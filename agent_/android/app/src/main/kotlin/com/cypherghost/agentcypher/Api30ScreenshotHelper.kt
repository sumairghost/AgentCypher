package com.cypherghost.agentcypher

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.os.Build
import android.util.Base64
import android.view.Display
import androidx.annotation.RequiresApi
import java.io.ByteArrayOutputStream

/** Android 11+ screenshot implementation kept outside the API-agnostic service class. */
object Api30ScreenshotHelper {
    @RequiresApi(Build.VERSION_CODES.R)
    fun capture(service: AccessibilityService, callback: (String?) -> Unit) {
        service.takeScreenshot(
            Display.DEFAULT_DISPLAY,
            service.mainExecutor,
            object : AccessibilityService.TakeScreenshotCallback {
                override fun onSuccess(screenshotResult: AccessibilityService.ScreenshotResult) {
                    val hardwareBuffer = screenshotResult.hardwareBuffer
                    val bitmap = Bitmap.wrapHardwareBuffer(
                        hardwareBuffer,
                        screenshotResult.colorSpace
                    )?.copy(Bitmap.Config.ARGB_8888, false)
                    hardwareBuffer.close()
                    if (bitmap == null) {
                        callback(null)
                        return
                    }
                    val output = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.JPEG, 60, output)
                    callback(Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP))
                }

                override fun onFailure(errorCode: Int) {
                    callback(null)
                }
            }
        )
    }
}
