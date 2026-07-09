package com.sonora.sonora

import android.content.Context
import android.media.AudioManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.sonora/volume"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "ensureMediaVolume" -> {
                    val wasRaised = ensureMediaVolume()
                    result.success(wasRaised)
                }
                "getMediaVolume" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    result.success(mapOf("current" to currentVol, "max" to maxVol))
                }
                "getAndroidSdk" -> {
                    result.success(android.os.Build.VERSION.SDK_INT)
                }
                "openFolder" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val opened = openFolder(filePath)
                        result.success(opened)
                    } else {
                        result.error("INVALID_ARGUMENT", "filePath is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openFolder(filePath: String): Boolean {
        return try {
            val file = java.io.File(filePath)
            val parentDir = file.parentFile ?: file
            if (!parentDir.exists()) return false

            val builder = android.os.StrictMode.VmPolicy.Builder()
            android.os.StrictMode.setVmPolicy(builder.build())

            val uri = android.net.Uri.fromFile(parentDir)
            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "*/*")
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun ensureMediaVolume(): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        if (currentVol == 0) {
            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            // Set to ~33% of max volume
            val targetVol = maxVol / 3
            audioManager.setStreamVolume(
                AudioManager.STREAM_MUSIC,
                if (targetVol > 0) targetVol else 1,
                0 // No flags — silent set, no UI popup
            )
            return true
        }
        return false
    }
}
