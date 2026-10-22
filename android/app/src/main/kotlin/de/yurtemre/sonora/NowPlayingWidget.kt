package de.yurtemre.sonora

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.os.Bundle
import android.os.SystemClock
import android.view.KeyEvent
import android.widget.RemoteViews
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Home screen "Now playing" widget.
 *
 * Dart pushes the current track over [CHANNEL] whenever the media item or the
 * playing flag changes. The state is persisted in its own SharedPreferences
 * file so the widget can re-render after a process restart.
 *
 * Transport buttons broadcast to [NowPlayingWidgetProvider], which forwards
 * them as MEDIA_BUTTON key events to audio_service's MediaButtonReceiver
 * while the playback service is up. When it is not (nothing queued, or the
 * process was killed), the buttons open the app instead: a cold
 * audio_service drops media keys that arrive before Dart has attached its
 * handler, and opening the app restores the last played queue.
 */
object NowPlayingWidget {
    const val CHANNEL = "de.yurtemre.sonora/home_widget"

    private const val PREFS = "sonora_home_widget"
    private const val KEY_HAS_TRACK = "has_track"
    private const val KEY_TITLE = "title"
    private const val KEY_ARTIST = "artist"
    private const val KEY_ART_PATH = "art_path"
    private const val KEY_PLAYING = "playing"

    const val ACTION_PLAY_PAUSE = "de.yurtemre.sonora.widget.PLAY_PAUSE"
    const val ACTION_NEXT = "de.yurtemre.sonora.widget.NEXT"
    const val ACTION_PREVIOUS = "de.yurtemre.sonora.widget.PREVIOUS"

    // Height from which the two-row layout with larger art is used.
    private const val LARGE_MIN_HEIGHT_DP = 100

    // Keeps RemoteViews bitmaps far below the binder transaction limit.
    private const val ART_MAX_PX = 320

    private val renderExecutor = Executors.newSingleThreadExecutor()

    data class State(
        val hasTrack: Boolean,
        val title: String?,
        val artist: String?,
        val artPath: String?,
        val playing: Boolean,
    )

    /** Handles widget updates from Dart on [messenger]. Safe to call repeatedly. */
    fun registerChannel(messenger: BinaryMessenger, context: Context) {
        val appContext = context.applicationContext
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "update" -> {
                    val args = call.arguments as? Map<*, *>
                    val state = if (args == null) {
                        State(false, null, null, null, false)
                    } else {
                        State(
                            hasTrack = true,
                            title = args["title"] as? String,
                            artist = args["artist"] as? String,
                            artPath = args["artPath"] as? String,
                            playing = args["isPlaying"] as? Boolean ?: false,
                        )
                    }
                    save(appContext, state)
                    renderExecutor.execute { renderAll(appContext) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Attaches the channel to audio_service's engine if it is running. */
    fun attachToRunningEngine(context: Context) {
        try {
            val engineId = com.ryanheise.audioservice.AudioServicePlugin.getFlutterEngineId()
            val engine = FlutterEngineCache.getInstance().get(engineId) ?: return
            registerChannel(engine.dartExecutor.binaryMessenger, context)
        } catch (_: Throwable) {
        }
    }

    private fun save(context: Context, state: State) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(KEY_HAS_TRACK, state.hasTrack)
            .putString(KEY_TITLE, state.title)
            .putString(KEY_ARTIST, state.artist)
            .putString(KEY_ART_PATH, state.artPath)
            .putBoolean(KEY_PLAYING, state.playing)
            .apply()
    }

    fun load(context: Context): State {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return State(
            hasTrack = prefs.getBoolean(KEY_HAS_TRACK, false),
            title = prefs.getString(KEY_TITLE, null),
            artist = prefs.getString(KEY_ARTIST, null),
            artPath = prefs.getString(KEY_ART_PATH, null),
            playing = prefs.getBoolean(KEY_PLAYING, false),
        )
    }

    /**
     * Whether audio_service's playback service is running with Dart attached,
     * so media keys reach the audio handler instead of being dropped.
     */
    fun isPlaybackServiceReady(): Boolean = try {
        val cls = Class.forName("com.ryanheise.audioservice.AudioService")
        fun staticField(name: String): Any? =
            cls.getDeclaredField(name).apply { isAccessible = true }.get(null)
        staticField("instance") != null && staticField("listener") != null
    } catch (_: Throwable) {
        false
    }

    fun renderAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, NowPlayingWidgetProvider::class.java))
        render(context, manager, ids)
    }

    fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
        if (ids.isEmpty()) return
        val state = load(context)
        val controlsPlayback = state.hasTrack && isPlaybackServiceReady()
        val artCache = HashMap<Int, Bitmap?>()
        for (id in ids) {
            val large = isLarge(manager.getAppWidgetOptions(id))
            val artSizePx = context.resources.getDimensionPixelSize(
                if (large) R.dimen.widget_art_size_large else R.dimen.widget_art_size,
            ).coerceAtMost(ART_MAX_PX)
            val art = if (state.hasTrack && state.artPath != null) {
                artCache.getOrPut(artSizePx) { loadArt(context, state.artPath, artSizePx) }
            } else {
                null
            }
            manager.updateAppWidget(id, buildViews(context, state, large, art, controlsPlayback))
        }
    }

    private fun isLarge(options: Bundle?): Boolean {
        val minHeight = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        return minHeight >= LARGE_MIN_HEIGHT_DP
    }

    private fun buildViews(
        context: Context,
        state: State,
        large: Boolean,
        art: Bitmap?,
        controlsPlayback: Boolean,
    ): RemoteViews {
        val layout = if (large) R.layout.widget_now_playing_large else R.layout.widget_now_playing
        val views = RemoteViews(context.packageName, layout)
        val openApp = openAppIntent(context)

        if (state.hasTrack) {
            views.setTextViewText(R.id.widget_title, state.title ?: "")
            views.setTextViewText(R.id.widget_artist, state.artist ?: "")
            if (art != null) {
                views.setImageViewBitmap(R.id.widget_art, art)
            } else {
                views.setImageViewResource(R.id.widget_art, R.drawable.widget_art_placeholder)
            }
        } else {
            views.setTextViewText(R.id.widget_title, context.getString(R.string.widget_nothing_playing))
            views.setTextViewText(R.id.widget_artist, context.getString(R.string.widget_tap_to_open))
            views.setImageViewResource(R.id.widget_art, R.mipmap.ic_launcher)
        }

        // A stored playing flag is stale once the service is gone.
        val playing = controlsPlayback && state.playing
        views.setImageViewResource(
            R.id.widget_play_pause,
            if (playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
        )
        views.setContentDescription(
            R.id.widget_play_pause,
            context.getString(if (playing) R.string.widget_pause else R.string.widget_play),
        )

        views.setOnClickPendingIntent(R.id.widget_art, openApp)
        views.setOnClickPendingIntent(R.id.widget_text, openApp)
        if (controlsPlayback) {
            views.setOnClickPendingIntent(R.id.widget_play_pause, actionIntent(context, ACTION_PLAY_PAUSE, 1))
            views.setOnClickPendingIntent(R.id.widget_next, actionIntent(context, ACTION_NEXT, 2))
            views.setOnClickPendingIntent(R.id.widget_previous, actionIntent(context, ACTION_PREVIOUS, 3))
        } else {
            views.setOnClickPendingIntent(R.id.widget_play_pause, openApp)
            views.setOnClickPendingIntent(R.id.widget_next, openApp)
            views.setOnClickPendingIntent(R.id.widget_previous, openApp)
        }
        return views
    }

    private fun launchIntent(context: Context): Intent =
        Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
        }

    private fun openAppIntent(context: Context): PendingIntent = PendingIntent.getActivity(
        context,
        0,
        launchIntent(context),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun actionIntent(context: Context, action: String, requestCode: Int): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            requestCode,
            Intent(context, NowPlayingWidgetProvider::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /** Forwards a widget button to the playback service, or opens the app. */
    fun handleAction(context: Context, action: String) {
        val keyCode = when (action) {
            ACTION_PLAY_PAUSE -> KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE
            ACTION_NEXT -> KeyEvent.KEYCODE_MEDIA_NEXT
            ACTION_PREVIOUS -> KeyEvent.KEYCODE_MEDIA_PREVIOUS
            else -> return
        }
        if (isPlaybackServiceReady()) {
            val now = SystemClock.uptimeMillis()
            val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                component = ComponentName(context, "com.ryanheise.audioservice.MediaButtonReceiver")
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0))
            }
            context.sendBroadcast(intent)
            return
        }
        // The service died since the widget was drawn: redraw so the buttons
        // open the app, and try to open it now.
        renderAll(context)
        try {
            context.startActivity(launchIntent(context))
        } catch (_: Exception) {
        }
    }

    private fun loadArt(context: Context, path: String, sizePx: Int): Bitmap? = try {
        val file = File(path)
        if (!file.isFile) {
            null
        } else {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= sizePx && bounds.outHeight / (sample * 2) >= sizePx) {
                sample *= 2
            }
            val decoded = BitmapFactory.decodeFile(
                path,
                BitmapFactory.Options().apply { inSampleSize = sample },
            )
            decoded?.let {
                val radius = context.resources.getDimension(R.dimen.widget_art_radius)
                roundedSquare(it, sizePx, radius)
            }
        }
    } catch (_: Throwable) {
        null
    }

    /** Center-crops [source] to a [size] square with rounded corners. */
    private fun roundedSquare(source: Bitmap, size: Int, radius: Float): Bitmap {
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val shader = BitmapShader(source, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        val scale = size.toFloat() / minOf(source.width, source.height)
        val matrix = android.graphics.Matrix().apply {
            setScale(scale, scale)
            postTranslate(
                (size - source.width * scale) / 2f,
                (size - source.height * scale) / 2f,
            )
        }
        shader.setLocalMatrix(matrix)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { this.shader = shader }
        Canvas(output).drawRoundRect(RectF(0f, 0f, size.toFloat(), size.toFloat()), radius, radius, paint)
        if (source !== output) source.recycle()
        return output
    }
}

class NowPlayingWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        NowPlayingWidget.attachToRunningEngine(context)
        when (val action = intent.action) {
            NowPlayingWidget.ACTION_PLAY_PAUSE,
            NowPlayingWidget.ACTION_NEXT,
            NowPlayingWidget.ACTION_PREVIOUS -> NowPlayingWidget.handleAction(context, action)
            else -> super.onReceive(context, intent)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        NowPlayingWidget.render(context, appWidgetManager, appWidgetIds)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        NowPlayingWidget.render(context, appWidgetManager, intArrayOf(appWidgetId))
    }
}
