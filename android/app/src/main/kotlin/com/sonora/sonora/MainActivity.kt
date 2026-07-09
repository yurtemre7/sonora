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

            // Try using the system file manager with the document URI
            val uri = androidx.core.content.FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                parentDir
            )

            // Strategy 1: Try ACTION_VIEW with DocumentsContract
            val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "resource/folder")
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }

            // Strategy 2: Try with vnd.android.document/directory mime type
            val intent2 = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "vnd.android.document/directory")
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            if (intent2.resolveActivity(packageManager) != null) {
                startActivity(intent2)
                return true
            }

            // Strategy 3: Fallback — just open any file manager
            val fallbackIntent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                data = android.net.Uri.parse("content://com.android.externalstorage.documents/document/primary:${parentDir.absolutePath.removePrefix("/storage/emulated/0/")}")
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            try {
                startActivity(fallbackIntent)
                true
            } catch (e: Exception) {
                // Final fallback — show chooser
                val chooserIntent = android.content.Intent.createChooser(
                    android.content.Intent(android.content.Intent.ACTION_GET_CONTENT).apply {
                        type = "*/*"
                        addCategory(android.content.Intent.CATEGORY_OPENABLE)
                    },
                    "Open folder: ${parentDir.name}"
                ).apply {
                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(chooserIntent)
                true
            }
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
