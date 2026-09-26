package com.cypherghost.agentcypher

import com.crsk.openclaw.OpenClawApp
import dagger.hilt.android.HiltAndroidApp

/**
 * Application class for the combined Agent Cypher APK.
 *
 * Hilt requires @HiltAndroidApp to be defined in the Gradle *application*
 * module, so it lives here (not on the 4AIs OpenClawApp base, which ships in
 * the :openclaw *library* module). Extends OpenClawApp so the 4AIs core's
 * StrictMode + Coil setup still runs at startup.
 */
@HiltAndroidApp
class CypherApp : OpenClawApp()