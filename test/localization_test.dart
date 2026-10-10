import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sonora/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Localization and material_ui delegates', () {
    testWidgets('Japanese locale resolves MaterialLocalizations and AppLocalizations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ja'),
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: _buildTestWidget,
            ),
          ),
        ),
      );

      expect(find.text('SONORA_JA_FOUND'), findsOneWidget);
    });

    testWidgets('English locale resolves MaterialLocalizations and AppLocalizations', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: _buildTestWidget,
            ),
          ),
        ),
      );

      expect(find.text('SONORA_JA_FOUND'), findsOneWidget);
    });
  });
}

Widget _buildTestWidget(BuildContext context) {
  // Verifies material_ui's MaterialLocalizations is found without throwing null error
  var materialLocalizations = MaterialLocalizations.of(context);
  var appLocalizations = AppLocalizations.of(context);

  if (materialLocalizations.okButtonLabel.isNotEmpty &&
      appLocalizations.appTitle.isNotEmpty) {
    return const Text('SONORA_JA_FOUND');
  }
  return const Text('FAILED');
}
