// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get aboutSonora => 'Über Sonora';

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Alben',
      one: '1 Album',
    );
    return '$_temp0';
  }

  @override
  String get albums => 'Alben';

  @override
  String get alreadyOnLatest => 'Sie verwenden bereits die neueste Version.';

  @override
  String get amoledDark => 'AMOLED Rein-Schwarz';

  @override
  String get amoledDarkSubtitle =>
      'Verwende tiefschwarze Hintergründe im Dunkelmodus statt Dunkelgrau';

  @override
  String get appLanguage => 'App-Sprache';

  @override
  String get appTitle => 'Sonora';

  @override
  String get appearance => 'Erscheinungsbild';

  @override
  String get appearanceSettings => 'Erscheinungsbild & Theme';

  @override
  String get appearanceSubtitle =>
      'Theme, Farben, Visualisierer, lokale Bilder';

  @override
  String artistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Künstler',
      one: '1 Künstler',
    );
    return '$_temp0';
  }

  @override
  String get artists => 'Künstler';

  @override
  String get autoCheckUpdates => 'Automatisch nach Updates suchen';

  @override
  String get autoCheckUpdatesSubtitle =>
      'Bei jedem App-Start GitHub auf neue Versionen prüfen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get change => 'Ändern';

  @override
  String get changeCover => 'Cover ändern';

  @override
  String get changeFolder => 'Ordner ändern';

  @override
  String get changelog => 'Änderungsprotokoll';

  @override
  String get changelogSubtitle => 'Neuigkeiten ansehen';

  @override
  String get changelogTitle => 'Änderungsprotokoll';

  @override
  String get checkForUpdates => 'Nach Updates suchen';

  @override
  String get checkForUpdatesSubtitle =>
      'GitHub nach einer neuen Version durchsuchen';

  @override
  String get chooseTheme => 'Theme wählen';

  @override
  String get close => 'Schließen';

  @override
  String get communityAndSupport => 'Community & Support';

  @override
  String get create => 'Erstellen';

  @override
  String get createPlaylist => 'Playlist erstellen';

  @override
  String get dangerZone => 'Gefahrenzone';

  @override
  String get dark => 'Dunkel';

  @override
  String get darkSubtitle => 'Immer dunkles Theme verwenden';

  @override
  String get dataManagement => 'Datenverwaltung';

  @override
  String get dateCreated => 'Erstellungsdatum';

  @override
  String get dateModified => 'Änderungsdatum';

  @override
  String get defaultAppColor => 'Standard-App-Farbe';

  @override
  String get defaultSleepTimer => 'Standard-Einschlaftimer';

  @override
  String get defaultSleepTimerSubtitle =>
      'Vorausgewählte Dauer beim Öffnen des Einschlaftimers';

  @override
  String get defaultStartPage => 'Standard-Startseite';

  @override
  String get defaultStartPageSubtitle =>
      'Seite, die beim App-Start angezeigt wird';

  @override
  String get delete => 'Löschen';

  @override
  String get deletePlaylist => 'Playlist löschen';

  @override
  String deletePlaylistConfirmMessage(String name) {
    return '\"$name\" löschen? Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get deletePlaylistConfirmTitle => 'Playlist löschen?';

  @override
  String get developerProfile => 'Entwicklerprofil';

  @override
  String get developerProfileSubtitle => 'yurtemre7 auf GitHub besuchen';

  @override
  String get displayedAs => 'Dargestellt als:';

  @override
  String get dynamicTheme => 'Dynamisches Theme (Material You)';

  @override
  String get dynamicThemeSubtitle =>
      'Farben der App automatisch an das aktive Album-Cover anpassen';

  @override
  String get enterYourName => 'Name eingeben';

  @override
  String get favorites => 'Favoriten';

  @override
  String get fileSize => 'Dateigröße';

  @override
  String get filterTitleArtist => 'Künstler aus Titeln entfernen';

  @override
  String get filterTitleArtistSubtitle =>
      'Blendet \"Künstler - \" am Anfang von Songtiteln aus.';

  @override
  String get filterTitleFeatures => '(feat.) aus Titeln entfernen';

  @override
  String get filterTitleFeaturesSubtitle =>
      'Blendet Gastkünstler aus dem Songtitel aus, falls vorhanden.';

  @override
  String get formattingSettings => 'Titel- & Metadatenformatierung';

  @override
  String get formattingSubtitle =>
      'Konfigurieren, wie Songtitel angezeigt werden';

  @override
  String goodAfternoon(String name) {
    return 'Guten Tag, $name';
  }

  @override
  String goodEvening(String name) {
    return 'Guten Abend, $name';
  }

  @override
  String goodMorning(String name) {
    return 'Guten Morgen, $name';
  }

  @override
  String get infoSettings => 'Info & Hilfe';

  @override
  String get infoSubtitle => 'Über, Updates, Änderungsprotokoll';

  @override
  String get keepPlayingOnClose => 'Beim Schließen weiterspielen';

  @override
  String get keepPlayingOnCloseSubtitle =>
      'Musik im Hintergrund weiterspielen, wenn die App weggewischt wird';

  @override
  String get language => 'Sprache';

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageJapanese => 'Japanisch';

  @override
  String get languageSystem => 'Systemstandard';

  @override
  String get lastSync => 'Letzte Synchronisation';

  @override
  String get libraryFormatting => 'Bibliotheksformatierung';

  @override
  String get librarySync => 'Bibliothek-Synchronisation';

  @override
  String get licenses => 'Lizenzen';

  @override
  String get licensesSubtitle => 'Open-Source-Lizenzen';

  @override
  String get light => 'Hell';

  @override
  String get lightSubtitle => 'Immer helles Theme verwenden';

  @override
  String get listeningStatistics => 'Hörstatistiken';

  @override
  String get lyrics => 'Songtext';

  @override
  String get mfx => 'MFX';

  @override
  String minuteAbbr(int min) {
    return '$min Min.';
  }

  @override
  String get neverSynced => 'Noch nie synchronisiert';

  @override
  String get noAlbumsFound => 'Keine Alben gefunden';

  @override
  String get noArtistsFound => 'Keine Künstler gefunden';

  @override
  String get noFavoritesYet => 'Noch keine Favoriten';

  @override
  String get noMatchingAlbumsFound => 'Keine passenden Alben gefunden';

  @override
  String get noMatchingArtistsFound => 'Keine passenden Künstler gefunden';

  @override
  String get noMatchingPlaylistsFound => 'Keine passenden Playlists gefunden';

  @override
  String get noMatchingSongsFound => 'Keine passenden Songs gefunden';

  @override
  String get noMusicFilesFound => 'Keine Musikdateien gefunden';

  @override
  String get noPlaylistsFound => 'Keine Playlists gefunden';

  @override
  String get noSongsFound => 'Keine Songs gefunden';

  @override
  String get ok => 'OK';

  @override
  String get openGithubReleases => 'GitHub-Releases öffnen';

  @override
  String get originalMetadata => 'Original-Metadaten:';

  @override
  String get pauseOnDuck => 'Bei Benachrichtigungen pausieren';

  @override
  String get pauseOnDuckSubtitle =>
      'Musik pausieren statt Lautstärke zu senken, wenn eine Benachrichtigung eingeht';

  @override
  String get permissionsExplained => 'Berechtigungen erklärt';

  @override
  String get personalization => 'Personalisierung';

  @override
  String get play => 'Wiedergabe';

  @override
  String get playAll => 'Alle wiedergeben';

  @override
  String get playback => 'Wiedergabe';

  @override
  String get playbackSettings => 'Wiedergabe & Audio';

  @override
  String get playbackSubtitle =>
      'Sleep-Timer, Startseite, Hintergrundwiedergabe';

  @override
  String playlistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Playlists',
      one: '1 Playlist',
    );
    return '$_temp0';
  }

  @override
  String get playlists => 'Playlists';

  @override
  String get preferLocalArtistImages => 'Lokale Künstlerbilder bevorzugen';

  @override
  String get preferLocalArtistImagesSubtitle =>
      'Lokale artist.jpg-Dateien aus Ihren Musikordnern verwenden, wenn verfügbar';

  @override
  String get preview => 'Vorschau';

  @override
  String get privacyCardDataContent =>
      'Diese App funktioniert vollständig offline und kommuniziert mit keinen Servern, außer zur Prüfung auf App-Updates via GitHub. Alle Bibliotheksstatistiken, Einstellungen und Wiedergabedaten verbleiben ausschließlich auf Ihrem Gerät und werden niemals übertragen.\n\nSie können darauf vertrauen, dass Ihre Hörgewohnheiten privat bleiben.';

  @override
  String get privacyCardDataTitle => 'Ihre Daten gehören Ihnen';

  @override
  String get privacyCardDeleteDataContent =>
      'Sie haben die volle Kontrolle. Alle App-Einstellungen, Statistiken und Caches können jederzeit sofort in der Gefahrenzone am Ende des Tabs \"Info & Support\" gelöscht werden.';

  @override
  String get privacyCardDeleteDataTitle => 'Alle Daten löschen';

  @override
  String get privacyCardInternetContent =>
      'Wird ausschließlich dazu verwendet, die aktuelle Version und das Änderungsprotokoll von GitHub abzurufen, um Sie über verfügbare Updates zu informieren.';

  @override
  String get privacyCardInternetTitle => 'Internet';

  @override
  String get privacyCardNotificationsContent =>
      'Wird verwendet, um die Mediensteuerung in der Benachrichtigungsleiste und auf dem Sperrbildschirm anzuzeigen. Ein Vordergrunddienst ist notwendig, damit die Musik im Hintergrund weiterläuft.';

  @override
  String get privacyCardNotificationsTitle =>
      'Benachrichtigungen & Vordergrunddienst';

  @override
  String get privacyCardStorageContent =>
      'Wird verwendet, um den ausgewählten Musikordner nach Audiodateien und lokalen Künstler-/Albumbildern (z. B. artist.jpg oder cover.png) zu durchsuchen.\n\nTransparenz-Garantie: Obwohl Android um Zugriff auf \"Fotos & Medien\" bittet, durchsucht Sonora ausschließlich Dateien im angegebenen Musikverzeichnis. Wir greifen NIEMALS auf Ihre persönliche Fotogalerie oder private Bilder zu.';

  @override
  String get privacyCardStorageTitle => 'Speicher, Audio & Coverbilder';

  @override
  String get privacyCardWakeLockContent =>
      'Verhindert, dass das Gerät in den Schlafmodus wechselt und die Musikwiedergabe unerwartet abbricht.';

  @override
  String get privacyCardWakeLockTitle => 'Wake Lock';

  @override
  String get privacyPermissions => 'Datenschutz & Berechtigungen';

  @override
  String get privacySettings => 'Datenschutz & Berechtigungen';

  @override
  String get privacySubtitle =>
      'Datenverwaltung und erforderliche Berechtigungen';

  @override
  String get rateLimitMessage =>
      'Das GitHub-API-Rate-Limit (60 Anfragen/Stunde für anonyme Anfragen) wurde erreicht.\n\nBitte öffnen Sie das GitHub-Repository direkt, um nach neuen Versionen zu suchen.';

  @override
  String get rateLimitTitle => 'Rate-Limit überschritten';

  @override
  String get removeCover => 'Cover entfernen';

  @override
  String get rename => 'Umbenennen';

  @override
  String get renamePlaylist => 'Playlist umbenennen';

  @override
  String get reset => 'Zurücksetzen';

  @override
  String get resetApplication => 'App zurücksetzen';

  @override
  String get resetApplicationConfirmMessage =>
      'Dabei werden alle importierten Audiodateien dauerhaft gelöscht und die Bibliothek geleert. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get resetApplicationConfirmTitle => 'App zurücksetzen?';

  @override
  String get resetApplicationSubtitle =>
      '3 Sekunden gedrückt halten, um alle Daten zu löschen.';

  @override
  String get resetStatistics => 'Statistiken zurücksetzen';

  @override
  String get resetStatisticsConfirmMessage =>
      'Dies löscht Ihre gesamten Hörstatistiken dauerhaft, einschließlich Gesamtdauer, Wiedergabezahlen und Top-Charts. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get resetStatisticsConfirmTitle => 'Statistiken zurücksetzen?';

  @override
  String get save => 'Speichern';

  @override
  String get searchAlbumsHint => 'Alben suchen...';

  @override
  String get searchArtistsHint => 'Künstler suchen...';

  @override
  String get searchPlaylistsHint => 'Playlists suchen...';

  @override
  String get searchSongsHint => 'Songs, Künstler suchen...';

  @override
  String get selectLanguage => 'Sprache wählen';

  @override
  String get setMusicDirectory => 'Musikverzeichnis festlegen';

  @override
  String get setSyncFolder => 'Sync-Ordner festlegen';

  @override
  String get settings => 'Einstellungen';

  @override
  String get showAudioVisualizer => 'Audio-Visualisierer anzeigen';

  @override
  String get showAudioVisualizerSubtitle =>
      'Audio-Wellen-Visualisierer im Player-Bildschirm animieren';

  @override
  String get shuffle => 'Zufall';

  @override
  String get shuffleAll => 'Alle zufällig';

  @override
  String get shufflePlay => 'Zufallswiedergabe';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Songs',
      one: '1 Song',
    );
    return '$_temp0';
  }

  @override
  String get songs => 'Songs';

  @override
  String get sort => 'Sortieren';

  @override
  String get sortAlbumsBy => 'Alben sortieren nach';

  @override
  String get sortArtistsBy => 'Künstler sortieren nach';

  @override
  String get sortAscending => 'Aufsteigend sortieren';

  @override
  String get sortByAlbumCount => 'Anzahl Alben';

  @override
  String get sortByAlbumName => 'Albumname';

  @override
  String get sortByArtist => 'Künstler';

  @override
  String get sortByArtistName => 'Künstlername';

  @override
  String get sortByDuration => 'Dauer';

  @override
  String get sortByName => 'Name';

  @override
  String get sortByPlaylistName => 'Playlist-Name';

  @override
  String get sortByRecentlyAdded => 'Kürzlich hinzugefügt';

  @override
  String get sortBySongCount => 'Anzahl Songs';

  @override
  String get sortByTitle => 'Titel';

  @override
  String get sortByTrackCount => 'Anzahl Titel';

  @override
  String get sortPlaylistsBy => 'Playlists sortieren nach';

  @override
  String get sortSongsBy => 'Songs sortieren nach';

  @override
  String get sortSubtitle =>
      'Ihre Sortiereinstellung wird pro Tab gespeichert und beim nächsten Start automatisch angewendet.';

  @override
  String get sourceCode => 'Quellcode';

  @override
  String get sourceCodeSubtitle => 'Das GitHub-Repository ansehen';

  @override
  String get stats => 'Statistiken';

  @override
  String get syncExplanation =>
      'Sonora spielt Ihre Dateien lokal und offline ab. Wenn Sie neue Titel in diesen Ordner kopieren, führen Sie unten eine Synchronisation aus.';

  @override
  String get syncNow => 'Jetzt synchronisieren';

  @override
  String get syncing => 'Synchronisieren...';

  @override
  String get systemDefault => 'Systemstandard';

  @override
  String get systemSubtitle => 'Folgt dem Theme Ihres Geräts';

  @override
  String get telegramContact => 'Telegram-Kontakt';

  @override
  String get telegramContactSubtitle => 'Über @emredev kontaktieren';

  @override
  String get themeMode => 'Theme-Modus';

  @override
  String get timer => 'Timer';

  @override
  String get titleFilters => 'Titel-Filter';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Titel',
      one: '1 Titel',
    );
    return '$_temp0';
  }

  @override
  String get updateCheckFailed =>
      'Update-Prüfung fehlgeschlagen. Bitte Internetverbindung prüfen.';

  @override
  String get useGreetingTitle => 'Begrüßungstitel verwenden';

  @override
  String get useGreetingTitleSubtitle =>
      'Zeitbasierte Begrüßung auf dem Startbildschirm statt App-Namen anzeigen';

  @override
  String get viewStatistics => 'Statistiken anzeigen';

  @override
  String get viewStatisticsSubtitle =>
      'Wiedergabeverlauf und Statistiken einsehen';

  @override
  String get volume => 'Lautstärke';

  @override
  String get yourName => 'Ihr Name';
}
