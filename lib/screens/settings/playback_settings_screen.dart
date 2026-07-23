import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sonora/providers/player_provider.dart';
import 'package:sonora/providers/settings_provider.dart';
import 'package:sonora/utils/l10n_extension.dart';

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
        title: Text(context.l10n.playback),
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
                      title: Text(context.l10n.keepPlayingOnClose),
                      subtitle: Text(context.l10n.keepPlayingOnCloseSubtitle),
                      value: settingsProvider.keepPlayingOnClose,
                      onChanged: (val) {
                        settingsProvider.setKeepPlayingOnClose(val);
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(
                        Icons.notifications_paused_rounded,
                      ),
                      title: Text(context.l10n.pauseOnDuck),
                      subtitle: Text(context.l10n.pauseOnDuckSubtitle),
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
              listenable: settingsProvider,
              builder: (context, _) {
                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text(context.l10n.defaultSleepTimer),
                      subtitle: Text(context.l10n.defaultSleepTimerSubtitle),
                      trailing: DropdownButton<int>(
                        value: settingsProvider.sleepTimerDefaultMinutes,
                        underline: const SizedBox(),
                        items: [5, 10, 15, 20, 25, 30, 60, 120]
                            .map(
                              (min) => DropdownMenuItem<int>(
                                value: min,
                                child: Text(context.l10n.minuteAbbr(min)),
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
                      title: Text(context.l10n.defaultStartPage),
                      subtitle: Text(context.l10n.defaultStartPageSubtitle),
                      trailing: DropdownButton<int>(
                        value: settingsProvider.defaultStartPage,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem<int>(
                            value: 0,
                            child: Text(context.l10n.songs),
                          ),
                          DropdownMenuItem<int>(
                            value: 1,
                            child: Text(context.l10n.albums),
                          ),
                          DropdownMenuItem<int>(
                            value: 2,
                            child: Text(context.l10n.artists),
                          ),
                          DropdownMenuItem<int>(
                            value: 3,
                            child: Text(context.l10n.playlists),
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
