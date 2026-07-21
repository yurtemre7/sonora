import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';

class PlaybackSettingsScreen extends StatelessWidget {
  const PlaybackSettingsScreen({
    super.key,
    required this.playerProvider,
    required this.settingsProvider,
  });

  final PlayerProvider playerProvider;
  final SettingsProvider settingsProvider;

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
            ListenableBuilder(
              listenable: settingsProvider,
              builder: (context, _) {
                return Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.play_circle_outline_rounded),
                      title: const Text('Keep playing on app close'),
                      subtitle: const Text(
                        'Keep playing music in the background when swiped away',
                      ),
                      value: settingsProvider.keepPlayingOnClose,
                      onChanged: (val) {
                        settingsProvider.setKeepPlayingOnClose(val);
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_paused_rounded),
                      title: const Text('Pause on notifications'),
                      subtitle: const Text(
                        'Pause music instead of lowering volume when a notification arrives',
                      ),
                      value: settingsProvider.pauseOnDuck,
                      onChanged: (val) {
                        settingsProvider.setPauseOnDuck(
                          val,
                          playerProvider.audioHandler,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            ListenableBuilder(
              listenable: playerProvider,
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
                        value: settingsProvider.sleepTimerDefaultMinutes,
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
                            settingsProvider.setSleepTimerDefaultMinutes(val);
                          }
                        },
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.home_outlined),
                      title: const Text('Default Start Page'),
                      subtitle: const Text('Page to show when the app starts'),
                      trailing: DropdownButton<int>(
                        value: settingsProvider.defaultStartPage,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem<int>(value: 0, child: Text('Songs')),
                          DropdownMenuItem<int>(
                            value: 1,
                            child: Text('Albums'),
                          ),
                          DropdownMenuItem<int>(
                            value: 2,
                            child: Text('Artists'),
                          ),
                          DropdownMenuItem<int>(
                            value: 3,
                            child: Text('Playlists'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            settingsProvider.setDefaultStartPage(val);
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
