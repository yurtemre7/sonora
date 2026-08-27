import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonora/l10n/app_localizations.dart';
import 'package:sonora/models/playlist.dart';
import 'package:sonora/widgets/animated_favorite_button.dart';
import 'package:sonora/widgets/confirm_delete_dialog.dart';
import 'package:sonora/widgets/edit_playlist_description_dialog.dart';
import 'package:sonora/widgets/rename_playlist_dialog.dart';
import 'package:sonora/widgets/speed_slider.dart';

Widget testApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('ConfirmDeleteDialog Tests', () {
    testWidgets('Returns true when destructive action is confirmed', (tester) async {
      bool? result;

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ConfirmDeleteDialog.show(
                    context,
                    title: 'Delete Playlist?',
                    message: 'This cannot be undone.',
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Playlist?'), findsOneWidget);
      expect(find.text('This cannot be undone.'), findsOneWidget);

      // Tap delete (confirm button)
      var deleteButton = find.byType(FilledButton);
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(result, isTrue);
    });

    testWidgets('Returns null/false when cancel button is tapped', (tester) async {
      bool? result;

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ConfirmDeleteDialog.show(
                    context,
                    title: 'Delete Song?',
                    message: 'Remove from device?',
                  );
                },
                child: const Text('Open Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap cancel button
      var cancelButton = find.byType(TextButton);
      expect(cancelButton, findsOneWidget);
      await tester.tap(cancelButton);
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });
  });

  group('RenamePlaylistDialog Tests', () {
    testWidgets('Loads initial playlist name and invokes onRename with new name', (tester) async {
      var playlist = Playlist(
        id: 'pl_123',
        name: 'Roadtrip 2026',
        songIds: [1, 2, 3],
      );

      String? renamedId;
      String? renamedTitle;

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  RenamePlaylistDialog.show(
                    context,
                    playlist: playlist,
                    onRename: (id, newName) async {
                      renamedId = id;
                      renamedTitle = newName;
                    },
                  );
                },
                child: const Text('Rename'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.text('Roadtrip 2026'), findsOneWidget);

      // Enter new name
      await tester.enterText(find.byType(TextField), 'Summer Vibes');
      await tester.pump();

      // Tap Save
      var saveButton = find.byType(FilledButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(renamedId, equals('pl_123'));
      expect(renamedTitle, equals('Summer Vibes'));
    });
  });

  group('EditPlaylistDescriptionDialog Tests', () {
    testWidgets('Loads current description and submits updated text', (tester) async {
      var playlist = Playlist(
        id: 'pl_desc',
        name: 'Chill Beats',
        songIds: [5],
        description: 'Old Description',
      );

      String? savedDescription;

      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  EditPlaylistDescriptionDialog.show(
                    context,
                    playlist: playlist,
                    onEdit: (newDesc) {
                      savedDescription = newDesc;
                    },
                  );
                },
                child: const Text('Edit Description'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Edit Description'));
      await tester.pumpAndSettle();

      expect(find.text('Old Description'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Relaxing lofi tracks for study');
      await tester.pump();

      var saveButton = find.byType(FilledButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(savedDescription, equals('Relaxing lofi tracks for study'));
    });
  });

  group('AnimatedFavoriteButton Tests', () {
    testWidgets('Renders favorite border icon and calls onToggle on tap', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        testApp(
          AnimatedFavoriteButton(
            isFavorite: false,
            onToggle: () => toggled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byType(AnimatedFavoriteButton));
      await tester.pump();

      expect(toggled, isTrue);
    });

    testWidgets('Renders filled favorite icon when isFavorite is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          AnimatedFavoriteButton(
            isFavorite: true,
            onToggle: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  group('SpeedSlider Widget Tests', () {
    testWidgets('Renders reset button and triggers onChanged when reset is tapped', (tester) async {
      double? changedSpeed;

      await tester.pumpWidget(
        testApp(
          SpeedSlider(
            speed: 1.5,
            onChanged: (val) => changedSpeed = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.speed_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.speed_rounded));
      await tester.pump();

      expect(changedSpeed, equals(1.0));
    });
  });
}
