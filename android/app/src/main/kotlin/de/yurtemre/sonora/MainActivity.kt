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
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path cannot be null", null)
                        return@setMethodCallHandler
                    }
                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "APK file does not exist", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val context = applicationContext
                        val apkUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            androidx.core.content.FileProvider.getUriForFile(
                                context,
                                "${context.packageName}.fileprovider",
                                file
                            )
                        } else {
                            Uri.fromFile(file)
                        }

                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                            setDataAndType(apkUri, "application/vnd.android.package-archive")
                            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }
                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = android.content.Intent(android.content.Intent.ACTION_VIEW, Uri.parse(url)).apply {
                            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                "getPackageInfo" -> {
                    try {
                        val pInfo = packageManager.getPackageInfo(packageName, 0)
                        val versionName = pInfo.versionName ?: "1.0.0"
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pInfo.longVersionCode
                        } else {
                            @Suppress("DEPRECATION")
                            pInfo.versionCode.toLong()
                        }
                        result.success(mapOf(
                            "appName" to "Sonora",
                            "packageName" to packageName,
                            "version" to versionName,
                            "buildNumber" to versionCode.toString()
                        ))
                    } catch (e: Exception) {
                        result.error("PACKAGE_INFO_ERROR", e.message, null)
                    }
                }
                "shareFiles" -> {
                    val filePaths = call.argument<List<String>>("filePaths")
                    val text = call.argument<String>("text")
                    val title = call.argument<String>("title") ?: "Share"

                    if (filePaths.isNullOrEmpty()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    try {
                        val context = applicationContext
                        val uris = ArrayList<Uri>()
                        for (path in filePaths) {
                            val file = File(path)
                            if (file.exists()) {
                                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    androidx.core.content.FileProvider.getUriForFile(
                                        context,
                                        "${context.packageName}.fileprovider",
                                        file
                                    )
                                } else {
                                    Uri.fromFile(file)
                                }
                                uris.add(uri)
                            }
                        }

                        if (uris.isEmpty()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        val intent = if (uris.size == 1) {
                            android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                                type = "*/*"
                                putExtra(android.content.Intent.EXTRA_STREAM, uris[0])
                                if (!text.isNullOrBlank()) {
                                    putExtra(android.content.Intent.EXTRA_TEXT, text)
                                }
                                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                            }
                        } else {
                            android.content.Intent(android.content.Intent.ACTION_SEND_MULTIPLE).apply {
                                type = "*/*"
                                putParcelableArrayListExtra(android.content.Intent.EXTRA_STREAM, uris)
                                if (!text.isNullOrBlank()) {
                                    putExtra(android.content.Intent.EXTRA_TEXT, text)
                                }
                                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                            }
                        }

                        val chooser = android.content.Intent.createChooser(intent, title).apply {
                            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(chooser)
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIASTORE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanMediaStore" -> {
                    val folderPath = call.argument<String>("folderPath")
                    val isFast = call.argument<Boolean>("isFast") ?: false
                    Thread {
                        val songs = queryMediaStore(folderPath, isFast)
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
                "openFileFolder" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path cannot be null", null)
                        return@setMethodCallHandler
                    }
                    val opened = openFileFolder(filePath)
                    result.success(opened)
                }
                "getDynamicWallpaperColor" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        try {
                            val color = getColor(android.R.color.system_accent1_600)
                            result.success(color)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    } else {
                        result.success(null)
                    }
                }
                "cropAndResizeImage" -> {
                    val sourcePath = call.argument<String>("sourcePath")
                    val targetPath = call.argument<String>("targetPath")
                    val targetSize = call.argument<Int>("targetSize") ?: 512
                    val quality = call.argument<Int>("quality") ?: 85

                    if (sourcePath == null || targetPath == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val srcFile = File(sourcePath)
                            if (!srcFile.exists()) {
                                runOnUiThread { result.success(false) }
                                return@Thread
                            }
                            val bitmap = android.graphics.BitmapFactory.decodeFile(sourcePath)
                            if (bitmap == null) {
                                runOnUiThread { result.success(false) }
                                return@Thread
                            }

                            val width = bitmap.width
                            val height = bitmap.height
                            val cropSize = if (width < height) width else height
                            val offsetX = (width - cropSize) / 2
                            val offsetY = (height - cropSize) / 2

                            val cropped = android.graphics.Bitmap.createBitmap(bitmap, offsetX, offsetY, cropSize, cropSize)
                            val scaled = if (cropSize > targetSize) {
                                android.graphics.Bitmap.createScaledBitmap(cropped, targetSize, targetSize, true)
                            } else {
                                cropped
                            }

                            val outFile = File(targetPath)
                            outFile.parentFile?.mkdirs()
                            FileOutputStream(outFile).use { out ->
                                scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, quality, out)
                            }

                            runOnUiThread { result.success(true) }
                        } catch (_: Exception) {
                            runOnUiThread { result.success(false) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openFileFolder(filePath: String): Boolean {
        try {
            val targetFile = File(filePath)
            val folder = if (targetFile.isDirectory) targetFile else (targetFile.parentFile ?: targetFile)
            val context = this

            // Strategy 1: Storage Access Framework / DocumentsUI Document URI
            val normPath = folder.absolutePath.replace('\\', '/')
            val primaryPrefixes = listOf("/storage/emulated/0/", "/sdcard/", "/storage/emulated/0", "/sdcard")
            var relPath = normPath
            for (p in primaryPrefixes) {
                if (normPath.startsWith(p, ignoreCase = true)) {
                    relPath = normPath.substring(p.length).trimStart('/')
                    break
                }
            }

            if (relPath.isNotEmpty() || normPath == "/storage/emulated/0" || normPath == "/sdcard") {
                val encodedRel = if (relPath.isEmpty()) "" else Uri.encode(relPath)
                val docUri = Uri.parse("content://com.android.externalstorage.documents/document/primary%3A$encodedRel")
                val intent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                    setDataAndType(docUri, "vnd.android.document/directory")
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                }
                try {
                    context.startActivity(intent)
                    return true
                } catch (_: Exception) {}

                val treeUri = Uri.parse("content://com.android.externalstorage.documents/tree/primary%3A$encodedRel")
                val treeIntent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                    setDataAndType(treeUri, "vnd.android.document/directory")
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                }
                try {
                    context.startActivity(treeIntent)
                    return true
                } catch (_: Exception) {}
            }

            // Strategy 2: FileProvider with resource/folder MIME type
            val folderUri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                try {
                    androidx.core.content.FileProvider.getUriForFile(
                        context,
                        "${context.packageName}.fileprovider",
                        folder
                    )
                } catch (_: Exception) {
                    Uri.fromFile(folder)
                }
            } else {
                Uri.fromFile(folder)
            }

            val folderIntent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                setDataAndType(folderUri, "resource/folder")
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            try {
                context.startActivity(folderIntent)
                return true
            } catch (_: Exception) {}

            // Strategy 3: FileProvider with directory MIME type
            val dirIntent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                setDataAndType(folderUri, "vnd.android.document/directory")
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            try {
                context.startActivity(dirIntent)
                return true
            } catch (_: Exception) {}

            // Strategy 4: FileProvider with */* MIME type
            val genericIntent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                setDataAndType(folderUri, "*/*")
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            try {
                context.startActivity(genericIntent)
                return true
            } catch (_: Exception) {}

            // Strategy 5: Open the file itself in default file/media viewer
            if (targetFile.exists() && targetFile.isFile) {
                val fileUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    try {
                        androidx.core.content.FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            targetFile
                        )
                    } catch (_: Exception) {
                        Uri.fromFile(targetFile)
                    }
                } else {
                    Uri.fromFile(targetFile)
                }
                val fileIntent = android.content.Intent(android.content.Intent.ACTION_VIEW).apply {
                    setDataAndType(fileUri, "*/*")
                    flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION
                }
                try {
                    context.startActivity(fileIntent)
                    return true
                } catch (_: Exception) {}
            }

            return false
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    private fun parseIndividualArtistsKotlin(artistString: String): List<String> {
        val trimmed = artistString.trim()
        if (trimmed.isEmpty()) return listOf("unknown artist")
        val rawList = trimmed.split(Regex("[,;/&\\\\]|\\s+(?:feat\\.?|ft\\.?|featuring|vs\\.?|with|[xX\\+])\\s+", RegexOption.IGNORE_CASE))
        val result = mutableListOf<String>()
        val seen = mutableSetOf<String>()
        for (name in rawList) {
            var clean = name.trim().replace(Regex("^[(\\[\\s]+|[)\\]\\s]+$"), "").trim()
            if (clean.isNotEmpty()) {
                val lower = clean.lowercase()
                if (!seen.contains(lower)) {
                    seen.add(lower)
                    result.add(clean)
                }
            }
        }
        return if (result.isEmpty()) listOf("unknown artist") else result
    }

    private fun resolveArtistImageFast(songFile: File, artistName: String, rootFolderPath: String?, folderFilesMap: MutableMap<String, Set<String>>): String? {
        val lowerArtist = artistName.lowercase().trim()
        val normRoot = rootFolderPath?.trimEnd('/', '\\')?.replace('\\', '/')

        var current: File? = songFile.parentFile
        while (current != null) {
            val normCurrent = current.absolutePath.replace('\\', '/')
            val filesInDir = folderFilesMap.getOrPut(normCurrent) {
                current.listFiles { file -> file.isFile }?.map { it.name.lowercase() }?.toSet() ?: emptySet()
            }

            if (filesInDir.isNotEmpty()) {
                val candidateNames = listOf("artist.jpg", "artist.png", "artist.webp", "artist.jpeg", "$lowerArtist.jpg", "$lowerArtist.png", "$lowerArtist.webp", "$lowerArtist.jpeg")
                for (cand in candidateNames) {
                    if (filesInDir.contains(cand)) {
                        return File(current, cand).absolutePath
                    }
                }
                val dirName = current.name.lowercase().trim()
                if (dirName == lowerArtist) {
                    val firstImage = current.listFiles { f -> f.isFile && f.extension.lowercase() in listOf("jpg", "jpeg", "png", "webp") }?.firstOrNull()
                    if (firstImage != null) {
                        return firstImage.absolutePath
                    }
                }
            }

            if (!normRoot.isNullOrEmpty() && normCurrent.equals(normRoot, ignoreCase = true)) break
            val parent = current.parentFile
            if (parent == null || parent.absolutePath == current.absolutePath) break
            current = parent
        }
        return null
    }

    private fun queryMediaStore(folderPath: String?, isFast: Boolean = false): Map<String, Any> {
        val totalStart = System.currentTimeMillis()
        val songsList = mutableListOf<Map<String, Any?>>()
        val artistImageMap = mutableMapOf<String, String>()
        val searchedArtists = mutableSetOf<String>()
        val folderFilesMap = mutableMapOf<String, Set<String>>()
        val missingAlbumIds = mutableListOf<Long>()
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
        val sortOrder: String? = null

        val normFolderPath = folderPath?.trimEnd('/', '\\')?.replace('\\', '/')
        val albumArtFileMap = mutableMapOf<Long, String?>()
        val cacheArtDir = File(cacheDir, "album_art")
        if (!cacheArtDir.exists()) {
            cacheArtDir.mkdirs()
        }

        var queryCursorMs: Long = 0
        var cursorLoopMs: Long = 0

        try {
            val queryStart = System.currentTimeMillis()
            val cursor = contentResolver.query(
                uri,
                projection.toTypedArray(),
                selection,
                null,
                sortOrder
            )
            queryCursorMs = System.currentTimeMillis() - queryStart

            cursor?.use { c ->
                val loopStart = System.currentTimeMillis()
                val idCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val durationCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val dataCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                val albumIdCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                val trackCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
                val yearCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
                val dateModifiedCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                val sizeCol = c.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)

                while (c.moveToNext()) {
                    val filePath = c.getString(dataCol) ?: continue
                    if (filePath.isEmpty()) continue

                    if (!normFolderPath.isNullOrEmpty()) {
                        val normFilePath = filePath.replace('\\', '/')
                        val altNormFolder = if (normFolderPath.startsWith("/sdcard", ignoreCase = true)) {
                            normFolderPath.replaceFirst("/sdcard", "/storage/emulated/0", ignoreCase = true)
                        } else if (normFolderPath.startsWith("/storage/emulated/0", ignoreCase = true)) {
                            normFolderPath.replaceFirst("/storage/emulated/0", "/sdcard", ignoreCase = true)
                        } else {
                            normFolderPath
                        }
                        if (!normFilePath.startsWith(normFolderPath, ignoreCase = true) &&
                            !normFilePath.startsWith(altNormFolder, ignoreCase = true)) {
                            continue
                        }
                    }

                    val id = c.getLong(idCol)
                    val rawTitle = c.getString(titleCol) ?: ""
                    val rawArtist = c.getString(artistCol) ?: ""
                    val rawAlbum = c.getString(albumCol) ?: ""
                    val duration = c.getLong(durationCol)
                    val albumId = c.getLong(albumIdCol)
                    val track = c.getInt(trackCol)
                    val year = c.getInt(yearCol)
                    val dateModified = c.getLong(dateModifiedCol) * 1000L
                    val size = c.getLong(sizeCol)

                    val title = if (rawTitle.isNotEmpty()) rawTitle else File(filePath).nameWithoutExtension
                    val artist = if (rawArtist.isNotEmpty() && rawArtist != "<unknown>") rawArtist else "Unknown Artist"
                    val album = if (rawAlbum.isNotEmpty() && rawAlbum != "<unknown>") rawAlbum else "Unknown Album"

                    // Resolve album art JPEG instantly from cache without blocking IO
                    if (!albumArtFileMap.containsKey(albumId)) {
                        val cachedArtFile = File(cacheArtDir, "art_album_$albumId.jpg")
                        if (cachedArtFile.exists() && cachedArtFile.length() > 0) {
                            albumArtFileMap[albumId] = cachedArtFile.absolutePath
                        } else {
                            albumArtFileMap[albumId] = null
                            if (albumId > 0) {
                                missingAlbumIds.add(albumId)
                            }
                        }
                    }
                    val artworkPath = albumArtFileMap[albumId]

                    // If not in fast mode, perform local artist image resolution
                    if (!isFast) {
                        val parsedArtists = parseIndividualArtistsKotlin(artist)
                        val songFile = File(filePath)
                        for (artistName in parsedArtists) {
                            val lowerArtist = artistName.lowercase().trim()
                            if (lowerArtist.isNotEmpty() && lowerArtist != "unknown artist" && !searchedArtists.contains(lowerArtist)) {
                                searchedArtists.add(lowerArtist)
                                val match = resolveArtistImageFast(songFile, artistName, normFolderPath, folderFilesMap)
                                if (match != null) {
                                    artistImageMap[lowerArtist] = match
                                }
                            }
                        }
                    }

                    val dotIdx = filePath.lastIndexOf('.')
                    val hasLyrics = if (dotIdx > 0) {
                        val prefix = filePath.substring(0, dotIdx)
                        File("$prefix.lrc").exists() || File("$prefix.txt").exists()
                    } else false

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
                        "album_id" to albumId,
                        "has_lyrics" to hasLyrics
                    )
                    songsList.add(songMap)
                }
                cursorLoopMs = System.currentTimeMillis() - loopStart
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Determine if this is a first scan (cache is cold — no album art files exist yet)
        val cacheWasEmpty = albumArtFileMap.values.all { it == null } && missingAlbumIds.isNotEmpty()

        if (cacheWasEmpty) {
            // First scan: extract album art AND resolve artist images synchronously
            for (aId in missingAlbumIds.distinct()) {
                val artFile = File(cacheArtDir, "art_album_$aId.jpg")
                if (!artFile.exists() || artFile.length() == 0L) {
                    val albumUri = ContentUris.withAppendedId(
                        Uri.parse("content://media/external/audio/albumart"),
                        aId
                    )
                    try {
                        contentResolver.openInputStream(albumUri)?.use { input ->
                            FileOutputStream(artFile).use { output ->
                                input.copyTo(output)
                            }
                        }
                    } catch (_: Exception) {
                        artFile.delete()
                    }
                }
                // Patch artworkPath in songsList for this albumId
                if (artFile.exists() && artFile.length() > 0) {
                    val artPath = artFile.absolutePath
                    albumArtFileMap[aId] = artPath
                    for (i in songsList.indices) {
                        val s = songsList[i]
                        if ((s["album_id"] as? Long) == aId) {
                            songsList[i] = s.toMutableMap().also { it["artwork_path"] = artPath }
                        }
                    }
                }
            }
            // Also resolve artist images on first scan
            for (song in songsList) {
                val fPath = song["file_path"] as? String ?: continue
                val rArtist = song["artist"] as? String ?: continue
                val parsed = parseIndividualArtistsKotlin(rArtist)
                for (aName in parsed) {
                    val lower = aName.lowercase().trim()
                    if (lower.isNotEmpty() && lower != "unknown artist" && !searchedArtists.contains(lower)) {
                        searchedArtists.add(lower)
                        val match = resolveArtistImageFast(File(fPath), aName, normFolderPath, folderFilesMap)
                        if (match != null) artistImageMap[lower] = match
                    }
                }
            }
        } else if (isFast && missingAlbumIds.isNotEmpty()) {
            // Subsequent scans: extract missing artwork + artist images in background (non-blocking)
            val songsCopy = ArrayList(songsList)
            Thread {
                for (aId in missingAlbumIds.distinct()) {
                    val artFile = File(cacheArtDir, "art_album_$aId.jpg")
                    if (!artFile.exists() || artFile.length() == 0L) {
                        val albumUri = ContentUris.withAppendedId(
                            Uri.parse("content://media/external/audio/albumart"),
                            aId
                        )
                        try {
                            contentResolver.openInputStream(albumUri)?.use { input ->
                                FileOutputStream(artFile).use { output ->
                                    input.copyTo(output)
                                }
                            }
                        } catch (_: Exception) {
                            artFile.delete()
                        }
                    }
                }
                // Resolve artist images and persist results so Dart can read them next scan
                val bgArtistMap = mutableMapOf<String, String>()
                val bgSearched = mutableSetOf<String>()
                for (song in songsCopy) {
                    val fPath = song["file_path"] as? String ?: continue
                    val rArtist = song["artist"] as? String ?: continue
                    val parsed = parseIndividualArtistsKotlin(rArtist)
                    for (aName in parsed) {
                        val lower = aName.lowercase().trim()
                        if (lower.isNotEmpty() && lower != "unknown artist" && !bgSearched.contains(lower)) {
                            bgSearched.add(lower)
                            val match = resolveArtistImageFast(File(fPath), aName, normFolderPath, folderFilesMap)
                            if (match != null) bgArtistMap[lower] = match
                        }
                    }
                }
                // Persist to artist_images.json for Dart to read on next loadLocalArtistImages()
                if (bgArtistMap.isNotEmpty()) {
                    try {
                        val appDocDir = applicationContext.getExternalFilesDir(null)
                            ?: applicationContext.filesDir
                        val imagesFile = java.io.File(appDocDir, "artist_images.json")
                        val existing = if (imagesFile.exists()) {
                            try {
                                org.json.JSONObject(imagesFile.readText())
                            } catch (_: Exception) { org.json.JSONObject() }
                        } else org.json.JSONObject()
                        for ((k, v) in bgArtistMap) existing.put(k, v)
                        imagesFile.writeText(existing.toString())
                    } catch (_: Exception) {}
                }
            }.start()
        }

        val totalKotlinMs = System.currentTimeMillis() - totalStart

        return mapOf(
            "songs" to songsList,
            "artist_images" to artistImageMap,
            "perf_query_cursor_ms" to queryCursorMs,
            "perf_cursor_loop_ms" to cursorLoopMs,
            "perf_total_kotlin_ms" to totalKotlinMs
        )
    }

    private fun resolveAlbumArtFile(albumId: Long, cacheDir: File, isFast: Boolean = false, missingAlbumIds: MutableList<Long>? = null): String? {
        if (albumId <= 0) return null
        val artFile = File(cacheDir, "art_album_$albumId.jpg")
        if (artFile.exists() && artFile.length() > 0) {
            return artFile.absolutePath
        }

        if (isFast) {
            missingAlbumIds?.add(albumId)
            return null
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

