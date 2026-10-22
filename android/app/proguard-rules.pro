# NowPlayingWidget reads these audio_service fields by reflection to tell
# whether the playback service is running with Dart attached.
-keepclassmembers class com.ryanheise.audioservice.AudioService {
    static com.ryanheise.audioservice.AudioService instance;
    static com.ryanheise.audioservice.AudioService$ServiceListener listener;
}
