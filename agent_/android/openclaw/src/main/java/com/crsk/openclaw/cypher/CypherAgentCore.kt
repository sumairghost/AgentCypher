package com.crsk.openclaw.cypher

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.ContextCompat
import com.crsk.openclaw.bootstrap.BootstrapManager
import com.crsk.openclaw.bootstrap.BootstrapState
import com.crsk.openclaw.bootstrap.GatewayProcess
import com.crsk.openclaw.bootstrap.GatewayStatus
import com.crsk.openclaw.data.model.ChatMessage
import com.crsk.openclaw.data.model.MessageRole
import com.crsk.openclaw.data.network.ChunkEvent
import com.crsk.openclaw.data.network.ws.ApprovalChannel
import com.crsk.openclaw.data.network.ws.ApprovalKind
import com.crsk.openclaw.data.network.ws.ChatSession
import com.crsk.openclaw.data.network.ws.RiskLevel
import com.crsk.openclaw.data.preferences.AppPreferences
import com.crsk.openclaw.data.providers.ProviderCatalog
import com.crsk.openclaw.overlay.AgentOverlayBridge
import com.crsk.openclaw.service.GatewayService
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Transport adapter between the Agent Cypher Flutter UI and the embedded
 * 4AIs/OpenClaw agent core.
 *
 * IMPORTANT: this class owns NO agent logic. It forwards calls to the real
 * 4AIs singletons (GatewayProcess, BootstrapManager, ChatSession,
 * ApprovalChannel, AppPreferences) and streams their events to Flutter.
 * The native agent core remains the single source of truth for task
 * execution; Flutter is a presentation layer.
 *
 * NOTE: the core is an android-library module; the Hilt plugin only runs for
 * the :app module, so this adapter uses plain constructor injection from the
 * :app module (see CypherCoreModule) instead of @EntryPoint/@Inject. That
 * keeps KSP clean in :openclaw while preserving the unmodified 4AIs @Inject
 * graph underneath.
 */
class CypherAgentCore(
    private val appContext: Context,
    private val gatewayProcess: GatewayProcess,
    private val bootstrapManager: BootstrapManager,
    private val chatSession: ChatSession,
    private val approvalChannel: ApprovalChannel,
    private val appPreferences: AppPreferences,
    private val overlayBridge: AgentOverlayBridge,
) {

    companion object {
        private const val TAG = "CypherAgentCore"
        const val METHOD_CHANNEL = "com.cypherghost.agentcypher/agentcore"
        const val EVENT_CHANNEL = "com.cypherghost.agentcypher/agentcore_events"
        const val GATEWAY_TIMEOUT_MS = 150_000L

        /** Shared instance wired from the app module (Flutter MainActivity). */
        @Volatile private var instance: CypherAgentCore? = null

        fun get(context: Context): CypherAgentCore =
            instance ?: throw IllegalStateException(
                "CypherAgentCore not attached — MainActivity must call " +
                    "CypherAgentCore.attach(...) in configureFlutterEngine().",
            )

        fun attach(core: CypherAgentCore) {
            instance = core
        }

        fun isAttached(): Boolean = instance != null
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val main = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var taskJob: Job? = null
    private var bootstrapWatchJob: Job? = null
    private var gatewayWatchJob: Job? = null
    private var approvalsWatchJob: Job? = null



    private fun emit(map: Map<String, Any?>) {
        main.post { eventSink?.success(map) }
    }

    private fun emitEvent(type: String, body: Map<String, Any?>) {
        emit(mapOf("type" to type) + body)
    }

    // ------------------------------------------------------------------
    // Flutter channel binding
    // ------------------------------------------------------------------

    fun bind(messenger: io.flutter.plugin.common.BinaryMessenger) {
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startEventWatchers()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    stopEventWatchers()
                }
            },
        )
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBootstrapped" -> result.success(bootstrapManager.isBootstrapped())
                "gatewayStatus" -> result.success(gatewayStatusMap())
                "startGateway" -> startGateway(result)
                "stopGateway" -> {
                    gatewayProcess.stop()
                    result.success(mapOf("ok" to true))
                }
                "bootstrap" -> bootstrap(result)
                "submitTask" -> {
                    val message = call.argument<String>("message") ?: ""
                    if (message.isBlank()) {
                        result.error("EMPTY_TASK", "Task message is empty", null)
                    } else {
                        submitTask(message)
                        result.success(mapOf("ok" to true))
                    }
                }
                "cancelTask" -> {
                    cancelTask()
                    result.success(mapOf("ok" to true))
                }
                "setProviderKey" -> {
                    val providerId = call.argument<String>("providerId") ?: ""
                    val key = call.argument<String>("key") ?: ""
                    scope.launch {
                        runCatching {
                            appPreferences.setProviderKey(providerId, key)
                            // Providers are re-derived from the keystore at the
                            // next gateway start (NodeProcess.refreshMcpConfig).
                            if (gatewayProcess.isRunning()) {
                                gatewayProcess.restart()
                            }
                        }.onSuccess { result.success(mapOf("ok" to true)) }
                            .onFailure { result.error("KEY_STORE_FAILED", it.message, null) }
                    }
                }
                "setSelectedProvider" -> {
                    val providerId = call.argument<String>("providerId") ?: ""
                    scope.launch {
                        runCatching { appPreferences.setApiProvider(providerId) }
                            .onSuccess { result.success(mapOf("ok" to true)) }
                            .onFailure { result.error("PREF_FAILED", it.message, null) }
                    }
                }
                "setSelectedModel" -> {
                    val modelId = call.argument<String>("modelId") ?: ""
                    scope.launch {
                        runCatching { appPreferences.setSelectedModel(modelId) }
                            .onSuccess { result.success(mapOf("ok" to true)) }
                            .onFailure { result.error("PREF_FAILED", it.message, null) }
                    }
                }
                "listProviders" -> result.success(listProviders())
                "resolveApproval" -> {
                    val id = call.argument<String>("id") ?: ""
                    val kind = runCatching {
                        ApprovalKind.valueOf(call.argument<String>("kind") ?: "Exec")
                    }.getOrDefault(ApprovalKind.Exec)
                    val allow = call.argument<Boolean>("allow") ?: false
                    scope.launch {
                        runCatching { approvalChannel.resolve(id, kind, allow) }
                            .onSuccess { result.success(mapOf("ok" to true)) }
                            .onFailure { result.error("APPROVAL_FAILED", it.message, null) }
                    }
                }
                "isAccessibilityEnabled" -> result.success(isCoreAccessibilityEnabled())
                "openCoreSetup" -> {
                    openCoreSetup()
                    result.success(mapOf("ok" to true))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun gatewayStatusMap(): Map<String, Any?> {
        val status = gatewayProcess.status.value
        return when (status) {
            is GatewayStatus.Running -> mapOf("state" to "running", "port" to status.port)
            is GatewayStatus.Starting -> mapOf("state" to "starting")
            is GatewayStatus.Failed -> mapOf("state" to "failed", "error" to status.error)
            GatewayStatus.Stopped -> mapOf("state" to "stopped")
        }
    }

    private fun listProviders(): List<Map<String, Any?>> {
        val prefs = appPreferences
        val selected = prefs.apiProvider.value
        return ProviderCatalog.all.map { p ->
            mapOf(
                "id" to p.id,
                "displayName" to p.displayName,
                "keyLabel" to p.keyLabel,
                "keyHint" to p.keyHint,
                "consoleUrl" to p.consoleUrl,
                "freeTier" to p.freeTier,
                "hasKey" to prefs.getProviderKey(p.id).isNotBlank(),
                "selected" to (p.id == selected),
                "models" to p.models.map { m ->
                    mapOf(
                        "id" to m.id,
                        "displayName" to m.displayName,
                        "reasoning" to m.reasoning,
                    )
                },
            )
        }
    }

    private fun startGateway(result: MethodChannel.Result) {
        scope.launch {
            try {
                val port = appPreferences.gatewayPort.value
                // The foreground service owns the wake lock, ShizukuBridge (:3001),
                // health monitoring and WS reconnection. It starts the gateway itself.
                ContextCompat.startForegroundService(
                    appContext,
                    Intent(appContext, GatewayService::class.java),
                )
                if (!gatewayProcess.isRunning()) {
                    gatewayProcess.start(port)
                }
                // Await a terminal status so Flutter gets a real answer, not "issued".
                val final = withTimeout(GATEWAY_TIMEOUT_MS) {
                    gatewayProcess.status.first {
                        it is GatewayStatus.Running || it is GatewayStatus.Failed
                    }
                }
                Log.i(TAG, "startGateway -> $final")
                result.success(gatewayStatusMap())
            } catch (t: Throwable) {
                Log.e(TAG, "startGateway failed", t)
                result.error("GATEWAY_START_FAILED", t.message, null)
            }
        }
    }

    private fun bootstrap(result: MethodChannel.Result) {
        val already = bootstrapWatchJob?.isActive == true
        result.success(mapOf("ok" to true, "alreadyRunning" to already))
        if (already) return
        bootstrapWatchJob = scope.launch {
            try {
                val port = appPreferences.gatewayPort.value
                bootstrapManager.bootstrap(port)
            } catch (t: Throwable) {
                Log.e(TAG, "bootstrap failed", t)
                emitEvent(
                    "bootstrap",
                    mapOf("state" to "failed", "error" to (t.message ?: "bootstrap failed")),
                )
            }
        }
    }

    private fun submitTask(message: String) {
        taskJob?.cancel()
        val prefs = appPreferences
        val providerId = prefs.apiProvider.value
        val modelId = prefs.selectedModel.value
        taskJob = scope.launch {
            val flow = chatSession.streamChat(
                messages = listOf(
                    ChatMessage(role = MessageRole.USER, content = message),
                ),
                providerId = providerId,
                bareModelId = modelId,
            )
            try {
                flow.collect { chunk -> emit(chunk.toMap()) }
                emitEvent("task", mapOf("state" to "done"))
            } catch (c: kotlinx.coroutines.CancellationException) {
                emitEvent("task", mapOf("state" to "cancelled"))
                throw c
            } catch (t: Throwable) {
                Log.e(TAG, "task stream failed", t)
                emitEvent("task", mapOf("state" to "failed", "error" to (t.message ?: "unknown")))
            }
        }
    }

    private fun cancelTask() {
        taskJob?.cancel()
        taskJob = null
        // Mirror 4AIs' own stop path: overlay stop notification, client-side detach.
        overlayBridge.onAgentStopped()
        emitEvent("task", mapOf("state" to "cancelled"))
    }

    private fun isCoreAccessibilityEnabled(): Boolean {
        return try {
            val enabled = Settings.Secure.getString(
                appContext.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ) ?: return false
            enabled.split(':').any {
                it.endsWith("com.crsk.openclaw.accessibility.PhoneAccessibilityService")
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun openCoreSetup() {
        try {
            val ctx = appContext
            ctx.startActivity(
                Intent(ctx, com.crsk.openclaw.ui.MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        } catch (t: Throwable) {
            Log.w(TAG, "openCoreSetup failed: ${t.message}")
        }
    }

    // ------------------------------------------------------------------
    // Event watchers (gateway status, bootstrap, approvals)
    // ------------------------------------------------------------------

    private fun startEventWatchers() {
        if (gatewayWatchJob == null) {
            gatewayWatchJob = scope.launch {
                gatewayProcess.status.collectLatest {
                    emitEvent("gateway", gatewayStatusMap())
                }
            }
        }
        if (approvalsWatchJob == null) {
            approvalChannel.start()
            approvalsWatchJob = scope.launch {
                approvalChannel.pending.collect { req ->
                    emitEvent(
                        "approval",
                        mapOf(
                            "id" to req.id,
                            "kind" to "Exec",
                            "summary" to req.summary,
                            "detail" to req.detail,
                            "riskLevel" to req.riskLevel.name,
                            "riskCategory" to req.riskCategory,
                        ),
                    )
                }
            }
        }
        if (bootstrapWatchJob == null) {
            bootstrapWatchJob = scope.launch {
                bootstrapManager.state.collectLatest { state ->
                    val body = when (state) {
                        is BootstrapState.Downloading ->
                            mapOf("state" to "downloading", "progress" to state.progress)
                        is BootstrapState.Extracting ->
                            mapOf("state" to "extracting", "progress" to state.progress)
                        is BootstrapState.Running ->
                            mapOf("state" to "running", "step" to state.step, "line" to state.line)
                        is BootstrapState.Failed ->
                            mapOf("state" to "failed", "error" to state.error)
                        BootstrapState.Complete -> mapOf("state" to "complete")
                        BootstrapState.FixingPaths -> mapOf("state" to "fixingPaths")
                        BootstrapState.NotStarted -> mapOf("state" to "notStarted")
                    }
                    emitEvent("bootstrap", body)
                }
            }
        }
    }

    private fun stopEventWatchers() {
        gatewayWatchJob?.cancel(); gatewayWatchJob = null
        approvalsWatchJob?.cancel(); approvalsWatchJob = null
        bootstrapWatchJob?.cancel(); bootstrapWatchJob = null
    }

    private fun ChunkEvent.toMap(): Map<String, Any?> = when (this) {
        is ChunkEvent.TextDelta -> mapOf(
            "kind" to "text", "text" to text,
        )
        is ChunkEvent.ToolStart -> mapOf(
            "kind" to "toolStart", "callId" to callId, "name" to name, "argsJson" to argsJson,
        )
        is ChunkEvent.ToolResult -> mapOf(
            "kind" to "toolResult", "callId" to callId, "name" to name, "ok" to ok, "text" to text,
        )
        is ChunkEvent.Lifecycle -> mapOf("kind" to "lifecycle", "phase" to phase)
        is ChunkEvent.AgentError -> mapOf(
            "kind" to "error", "text" to text, "recoverable" to recoverable,
        )
        is ChunkEvent.Usage -> mapOf(
            "kind" to "usage", "inputTokens" to inputTokens, "outputTokens" to outputTokens,
        )
        ChunkEvent.Done -> mapOf("kind" to "done")
    }
}
