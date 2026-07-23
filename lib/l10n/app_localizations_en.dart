// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get aboutSonora => 'About Sonora';

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String get albums => 'Albums';

  @override
  String get alreadyOnLatest => 'You are already on the latest version.';

  @override
  String get amoledDark => 'AMOLED Pure Black';

  @override
  String get amoledDarkSubtitle =>
      'Use pitch black backgrounds in dark mode instead of dark gray';

  @override
  String get appLanguage => 'App Language';

  @override
  String get appTitle => 'Sonora';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceSettings => 'Appearance & Theme';

  @override
  String get appearanceSubtitle => 'Theme, colors, visualizer, local images';

  @override
  String artistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artists',
      one: '1 artist',
    );
    return '$_temp0';
  }

  @override
  String get artists => 'Artists';

  @override
  String get autoCheckUpdates => 'Automatically Check for Updates';

  @override
  String get autoCheckUpdatesSubtitle =>
      'Check GitHub for releases every time the app opens';

  @override
  String get cancel => 'Cancel';

  @override
  String get change => 'Change';

  @override
  String get changeCover => 'Change Cover';

  @override
  String get changeFolder => 'Change Folder';

  @override
  String get changelog => 'Changelog';

  @override
  String get changelogSubtitle => 'View what\'s new';

  @override
  String get changelogTitle => 'Changelog';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get checkForUpdatesSubtitle => 'Check GitHub for a new release';

  @override
  String get chooseTheme => 'Choose Theme';

  @override
  String get close => 'Close';

  @override
  String get communityAndSupport => 'Community & Support';

  @override
  String get create => 'Create';

  @override
  String get createPlaylist => 'Create a playlist';

  @override
  String get dangerZone => 'Danger Zone';

  @override
  String get dark => 'Dark';

  @override
  String get darkSubtitle => 'Always use dark theme';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get dateCreated => 'Date Created';

  @override
  String get dateModified => 'Date Modified';

  @override
  String get defaultAppColor => 'Default App Color';

  @override
  String get defaultSleepTimer => 'Default Sleep Timer';

  @override
  String get defaultSleepTimerSubtitle =>
      'Default duration selected when opening the sleep timer';

  @override
  String get defaultStartPage => 'Default Start Page';

  @override
  String get defaultStartPageSubtitle => 'Page to show when the app starts';

  @override
  String get delete => 'Delete';

  @override
  String get deletePlaylist => 'Delete Playlist';

  @override
  String deletePlaylistConfirmMessage(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get deletePlaylistConfirmTitle => 'Delete Playlist?';

  @override
  String get developerProfile => 'Developer Profile';

  @override
  String get developerProfileSubtitle => 'Check out yurtemre7 on GitHub';

  @override
  String get displayedAs => 'Displayed As:';

  @override
  String get dynamicTheme => 'Dynamic Theme (Material You)';

  @override
  String get dynamicThemeSubtitle =>
      'Automatically theme the app using active album art';

  @override
  String get enterYourName => 'Enter Your Name';

  @override
  String get favorites => 'Favorites';

  @override
  String get fileSize => 'File Size';

  @override
  String get filterTitleArtist => 'Remove artist from titles';

  @override
  String get filterTitleArtistSubtitle =>
      'Hides \"Artist - \" from the beginning of song titles.';

  @override
  String get filterTitleFeatures => 'Remove (feat.) from titles';

  @override
  String get filterTitleFeaturesSubtitle =>
      'Hides featured artists from the song title if present.';

  @override
  String get formattingSettings => 'Title & Metadata Formatting';

  @override
  String get formattingSubtitle => 'Configure how song titles are displayed';

  @override
  String goodAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String goodEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String goodMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String get infoSettings => 'Info & Support';

  @override
  String get infoSubtitle => 'About, updates, changelog, danger zone';

  @override
  String get keepPlayingOnClose => 'Keep playing on app close';

  @override
  String get keepPlayingOnCloseSubtitle =>
      'Keep playing music in the background when swiped away';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'German';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageSystem => 'System Default';

  @override
  String get lastSync => 'Last Sync';

  @override
  String get libraryFormatting => 'Library Formatting';

  @override
  String get librarySync => 'Library Sync';

  @override
  String get licenses => 'Licenses';

  @override
  String get licensesSubtitle => 'Open source licenses';

  @override
  String get light => 'Light';

  @override
  String get lightSubtitle => 'Always use light theme';

  @override
  String get listeningStatistics => 'Listening Statistics';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get mfx => 'MFX';

  @override
  String minuteAbbr(int min) {
    return '$min min';
  }

  @override
  String get neverSynced => 'Never synced';

  @override
  String get noAlbumsFound => 'No albums found';

  @override
  String get noArtistsFound => 'No artists found';

  @override
  String get noFavoritesYet => 'No favorites yet';

  @override
  String get noMatchingAlbumsFound => 'No matching albums found';

  @override
  String get noMatchingArtistsFound => 'No matching artists found';

  @override
  String get noMatchingPlaylistsFound => 'No matching playlists found';

  @override
  String get noMatchingSongsFound => 'No matching songs found';

  @override
  String get noMusicFilesFound => 'No music files found';

  @override
  String get noPlaylistsFound => 'No playlists found';

  @override
  String get noSongsFound => 'No songs found';

  @override
  String get ok => 'OK';

  @override
  String get openGithubReleases => 'Open GitHub Releases';

  @override
  String get originalMetadata => 'Original Metadata:';

  @override
  String get pauseOnDuck => 'Pause on notifications';

  @override
  String get pauseOnDuckSubtitle =>
      'Pause music instead of lowering volume when a notification arrives';

  @override
  String get permissionsExplained => 'Permissions Explained';

  @override
  String get personalization => 'Personalization';

  @override
  String get play => 'Play';

  @override
  String get playAll => 'Play All';

  @override
  String get playback => 'Playback';

  @override
  String get playbackSettings => 'Playback & Audio';

  @override
  String get playbackSubtitle => 'Sleep timer, start page, background play';

  @override
  String playlistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
    );
    return '$_temp0';
  }

  @override
  String get playlists => 'Playlists';

  @override
  String get preferLocalArtistImages => 'Prefer Local Artist Images';

  @override
  String get preferLocalArtistImagesSubtitle =>
      'Use local artist.jpg files from your music folders when available';

  @override
  String get preview => 'Preview';

  @override
  String get privacyCardDataContent =>
      'This app operates entirely offline and communicates with no servers, with the exception of checking GitHub for app updates. All of your library statistics, preferences, and playtime data stay strictly on your device and are never sent anywhere. \n\nYou can trust that your listening habits remain private.';

  @override
  String get privacyCardDataTitle => 'Your Data is Yours';

  @override
  String get privacyCardDeleteDataContent =>
      'You have full control. You can wipe all app settings, statistics, and caches instantly at any time from the Danger Zone located at the bottom of the Info & Support tab.';

  @override
  String get privacyCardDeleteDataTitle => 'Delete All Data';

  @override
  String get privacyCardInternetContent =>
      'Only used to fetch the latest release version and changelog from GitHub to notify you of available updates.';

  @override
  String get privacyCardInternetTitle => 'Internet';

  @override
  String get privacyCardNotificationsContent =>
      'Used to display the media player controls in your notification shade and lock screen. A foreground service is required to keep the music playing continuously in the background when the app is closed.';

  @override
  String get privacyCardNotificationsTitle =>
      'Notifications & Foreground Service';

  @override
  String get privacyCardStorageContent =>
      'Used to scan your selected music folder for audio tracks and local artist/album artwork (e.g., artist.jpg or cover.png).\n\nTransparent Privacy Guarantee: Although Android prompts for \"Photos & Media\" access, Sonora strictly scans files inside your designated music directory. We NEVER read, inspect, or access your personal photo gallery, camera roll, or private images.';

  @override
  String get privacyCardStorageTitle => 'Storage, Audio & Cover Images';

  @override
  String get privacyCardWakeLockContent =>
      'Prevents your device from sleeping and abruptly stopping the music playback while you are listening.';

  @override
  String get privacyCardWakeLockTitle => 'Wake Lock';

  @override
  String get privacyPermissions => 'Privacy & Permissions';

  @override
  String get privacySettings => 'Privacy & Permissions';

  @override
  String get privacySubtitle => 'Data management and required permissions';

  @override
  String get rateLimitMessage =>
      'GitHub API rate limit (60 requests/hour for anonymous requests) has been reached.\n\nPlease open the GitHub repository directly to check for new releases.';

  @override
  String get rateLimitTitle => 'Rate Limit Exceeded';

  @override
  String get removeCover => 'Remove Cover';

  @override
  String get rename => 'Rename';

  @override
  String get renamePlaylist => 'Rename Playlist';

  @override
  String get reset => 'Reset';

  @override
  String get resetApplication => 'Reset Application';

  @override
  String get resetApplicationConfirmMessage =>
      'This will permanently delete all imported audio files and clear your library. This cannot be undone.';

  @override
  String get resetApplicationConfirmTitle => 'Reset Application?';

  @override
  String get resetApplicationSubtitle => 'Hold for 3 seconds to wipe all data.';

  @override
  String get resetStatistics => 'Reset Statistics';

  @override
  String get resetStatisticsConfirmMessage =>
      'This will permanently delete all your listening statistics, including total time, play counts, and top charts. This cannot be undone.';

  @override
  String get resetStatisticsConfirmTitle => 'Reset Statistics?';

  @override
  String get save => 'Save';

  @override
  String get searchAlbumsHint => 'Search albums...';

  @override
  String get searchArtistsHint => 'Search artists...';

  @override
  String get searchPlaylistsHint => 'Search playlists...';

  @override
  String get searchSongsHint => 'Search songs, artists...';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get setMusicDirectory => 'Set Music Directory';

  @override
  String get setSyncFolder => 'Set Sync Folder';

  @override
  String get settings => 'Settings';

  @override
  String get showAudioVisualizer => 'Show Audio Visualizer';

  @override
  String get showAudioVisualizerSubtitle =>
      'Animate audio wave visualizer inside player screen';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get shuffleAll => 'Shuffle All';

  @override
  String get shufflePlay => 'Shuffle Play';

  @override
  String songCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String get songs => 'Songs';

  @override
  String get sort => 'Sort';

  @override
  String get sortAlbumsBy => 'Sort Albums By';

  @override
  String get sortArtistsBy => 'Sort Artists By';

  @override
  String get sortAscending => 'Sort Ascending';

  @override
  String get sortByAlbumCount => 'Album Count';

  @override
  String get sortByAlbumName => 'Album Name';

  @override
  String get sortByArtist => 'Artist';

  @override
  String get sortByArtistName => 'Artist Name';

  @override
  String get sortByDuration => 'Duration';

  @override
  String get sortByName => 'Name';

  @override
  String get sortByPlaylistName => 'Playlist Name';

  @override
  String get sortByRecentlyAdded => 'Recently Added';

  @override
  String get sortBySongCount => 'Song Count';

  @override
  String get sortByTitle => 'Title';

  @override
  String get sortByTrackCount => 'Track Count';

  @override
  String get sortPlaylistsBy => 'Sort Playlists By';

  @override
  String get sortSongsBy => 'Sort Songs By';

  @override
  String get sortSubtitle =>
      'Your sorting preference will be saved per tab and automatically applied on next startup.';

  @override
  String get sourceCode => 'Source Code';

  @override
  String get sourceCodeSubtitle => 'View the GitHub repository';

  @override
  String get stats => 'Stats';

  @override
  String get syncExplanation =>
      'Sonora plays your files locally and offline. When you copy new tracks into this folder, run a sync below to add them to your library.';

  @override
  String get syncNow => 'Sync Now';

  @override
  String get syncing => 'Syncing...';

  @override
  String get systemDefault => 'System Default';

  @override
  String get systemSubtitle => 'Follows your device theme';

  @override
  String get telegramContact => 'Telegram Contact';

  @override
  String get telegramContactSubtitle => 'Reach out via @emredev';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get timer => 'Timer';

  @override
  String get titleFilters => 'Title Filters';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String get updateCheckFailed =>
      'Failed to check for updates. Check your internet connection.';

  @override
  String get useGreetingTitle => 'Use Greeting Title';

  @override
  String get useGreetingTitleSubtitle =>
      'Show a time-based greeting on the home screen instead of the app name';

  @override
  String get viewStatistics => 'View Statistics';

  @override
  String get viewStatisticsSubtitle => 'See your playback history and stats';

  @override
  String get volume => 'Volume';

  @override
  String get yourName => 'Your Name';
}
