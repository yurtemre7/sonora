package de.yurtemre.sonora

import android.content.ContentUris
import android.content.Context
import android.media.AudioManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import androidx.core.view.WindowCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
    private val VOLUME_CHANNEL = "de.yurtemre.sonora/volume"
    private val MEDIASTORE_CHANNEL = "de.yurtemre.sonora/mediastore"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOLUME_CHANNEL).setMethodCallHandler { call, result ->
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
                    result.success(Build.VERSION.SDK_INT)
                }
                "getDeviceAbi" -> {
                    val abis = Build.SUPPORTED_ABIS
                    val primaryAbi = if (abis != null && abis.isNotEmpty()) abis[0] else ""
                    val normalizedAbi = when {
                        primaryAbi.contains("arm64", ignoreCase = true) || primaryAbi.contains("aarch64", ignoreCase = true) -> "arm64-v8a"
                        primaryAbi.contains("v7", ignoreCase = true) || primaryAbi.contains("arm", ignoreCase = true) -> "armeabi-v7a"
                        primaryAbi.contains("x86_64", ignoreCase = true) -> "x86_64"
                        primaryAbi.contains("x86", ignoreCase = true) -> "x86"
                        else -> primaryAbi
                    }
                    result.success(normalizedAbi)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIASTORE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanMediaStore" -> {
                    val folderPath = call.argument<String>("folderPath")
                    Thread {
                        val songs = queryMediaStore(folderPath)
                        runOnUiThread {
                            result.success(songs)
                        }
                    }.start()
                }
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun queryMediaStore(folderPath: String?): List<Map<String, Any?>> {
        val songsList = mutableListOf<Map<String, Any?>>()
        val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

        val projection = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.ALBUM_ID,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.SIZE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            projection.add(MediaStore.Audio.Media.COMPOSER)
        }

        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} ASC"

        val normFolderPath = folderPath?.trimEnd('/', '\\')?.replace('\\', '/')

        // Pre-cache album artwork files
        val albumArtFileMap = mutableMapOf<Long, String?>()

        try {
            contentResolver.query(
                uri,
                projection.toTypedArray(),
                selection,
                null,
                sortOrder
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                val trackCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
                val yearCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
                val dateModifiedCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)

                val cacheArtDir = File(cacheDir, "album_art")
                if (!cacheArtDir.exists()) {
                    cacheArtDir.mkdirs()
                }

                while (cursor.moveToNext()) {
                    val filePath = cursor.getString(dataCol) ?: continue
                    if (filePath.isEmpty()) continue

                    // Check folderPath filter if provided
                    if (!normFolderPath.isNullOrEmpty()) {
                        val normFilePath = filePath.replace('\\', '/')
                        if (!normFilePath.startsWith(normFolderPath, ignoreCase = true)) {
                            continue
                        }
                    }

                    val id = cursor.getLong(idCol)
                    val rawTitle = cursor.getString(titleCol) ?: ""
                    val rawArtist = cursor.getString(artistCol) ?: ""
                    val rawAlbum = cursor.getString(albumCol) ?: ""
                    val duration = cursor.getLong(durationCol)
                    val albumId = cursor.getLong(albumIdCol)
                    val track = cursor.getInt(trackCol)
                    val year = cursor.getInt(yearCol)
                    val dateModified = cursor.getLong(dateModifiedCol) * 1000L
                    val size = cursor.getLong(sizeCol)

                    // Format title / artist / album if MediaStore returns defaults like <unknown>
                    val title = if (rawTitle.isNotEmpty()) rawTitle else File(filePath).nameWithoutExtension
                    val artist = if (rawArtist.isNotEmpty() && rawArtist != "<unknown>") rawArtist else "Unknown Artist"
                    val album = if (rawAlbum.isNotEmpty() && rawAlbum != "<unknown>") rawAlbum else "Unknown Album"

                    // Resolve or copy album art JPEG for this albumId if not done yet
                    if (!albumArtFileMap.containsKey(albumId)) {
                        albumArtFileMap[albumId] = resolveAlbumArtFile(albumId, cacheArtDir)
                    }
                    val artworkPath = albumArtFileMap[albumId]

                    val songMap = mapOf(
                        "id" to id,
                        "title" to title,
                        "artist" to artist,
                        "album" to album,
                        "duration_ms" to duration,
                        "file_path" to filePath,
                        "artwork_path" to artworkPath,
                        "track_number" to track,
                        "year" to year,
                        "last_modified_ms" to dateModified,
                        "file_size" to size,
                        "album_id" to albumId
                    )
                    songsList.add(songMap)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return songsList
    }

    private fun resolveAlbumArtFile(albumId: Long, cacheDir: File): String? {
        if (albumId <= 0) return null
        val artFile = File(cacheDir, "art_album_$albumId.jpg")
        if (artFile.exists() && artFile.length() > 0) {
            return artFile.absolutePath
        }

        val albumUri = ContentUris.withAppendedId(
            Uri.parse("content://media/external/audio/albumart"),
            albumId
        )

        try {
            contentResolver.openInputStream(albumUri)?.use { input ->
                FileOutputStream(artFile).use { output ->
                    input.copyTo(output)
                }
            }
            if (artFile.exists() && artFile.length() > 0) {
                return artFile.absolutePath
            }
        } catch (_: Exception) {
            artFile.delete()
        }
        return null
    }

    private fun ensureMediaVolume(): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val currentVol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC)
        if (currentVol == 0) {
            val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
            val targetVol = maxVol / 3
            audioManager.setStreamVolume(
                AudioManager.STREAM_MUSIC,
                if (targetVol > 0) targetVol else 1,
                0
            )
            return true
        }
        return false
    }
}

