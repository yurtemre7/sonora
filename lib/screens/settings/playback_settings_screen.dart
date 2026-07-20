import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sonora/providers/player_provider.dart';

class PlaybackSettingsScreen extends StatefulWidget {
  const PlaybackSettingsScreen({super.key, required this.playerProvider});

  final PlayerProvider playerProvider;

  @override
  State<PlaybackSettingsScreen> createState() => _PlaybackSettingsScreenState();
}

class _PlaybackSettingsScreenState extends State<PlaybackSettingsScreen> {
  var _keepPlayingOnClose = false;
  var _pauseOnDuck = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var prefs = SharedPreferencesAsync();
    var keepPlaying = await prefs.getBool('keep_playing_on_close') ?? false;
    var pauseOnDuck = await prefs.getBool('pause_on_duck') ?? false;

    if (!mounted) return;
    setState(() {
      _keepPlayingOnClose = keepPlaying;
      _pauseOnDuck = pauseOnDuck;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playback'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Keep playing on app close'),
              subtitle: const Text(
                'Keep playing music in the background when swiped away',
              ),
              value: _keepPlayingOnClose,
              onChanged: (val) async {
                var prefs = SharedPreferencesAsync();
                await prefs.setBool('keep_playing_on_close', val);
                setState(() {
                  _keepPlayingOnClose = val;
                });
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_paused_rounded),
              title: const Text('Pause on notifications'),
              subtitle: const Text(
                'Pause music instead of lowering volume when a notification arrives',
              ),
              value: _pauseOnDuck,
              onChanged: (val) async {
                var prefs = SharedPreferencesAsync();
                await prefs.setBool('pause_on_duck', val);
                await widget.playerProvider.audioHandler.setPauseOnDuck(val);
                setState(() {
                  _pauseOnDuck = val;
                });
              },
            ),
            ListenableBuilder(
              listenable: widget.playerProvider,
              builder: (context, _) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('Default Sleep Timer'),
                      subtitle: const Text(
                        'Default duration selected when opening the sleep timer',
                      ),
                      trailing: DropdownButton<int>(
                        value: widget.playerProvider.sleepTimerDefaultMinutes,
                        underline: const SizedBox(),
                        items: [5, 10, 15, 20, 25, 30, 60, 120]
                            .map(
                              (min) => DropdownMenuItem<int>(
                                value: min,
                                child: Text('$min min'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            widget.playerProvider.setSleepTimerDefaultMinutes(
                              val,
                            );
                          }
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('Default Start Page'),
                      subtitle: const Text('Page to show when the app starts'),
                      trailing: DropdownButton<int>(
                        value: widget.playerProvider.defaultStartPage,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem<int>(value: 0, child: Text('Songs')),
                          DropdownMenuItem<int>(value: 1, child: Text('Albums')),
                          DropdownMenuItem<int>(value: 2, child: Text('Artists')),
                          DropdownMenuItem<int>(
                            value: 3,
                            child: Text('Playlists'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            widget.playerProvider.setDefaultStartPage(val);
                          }
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
