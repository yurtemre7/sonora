import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('ja'),
  ];

  /// No description provided for @aboutSonora.
  ///
  /// In en, this message translates to:
  /// **'About Sonora'**
  String get aboutSonora;

  /// No description provided for @accessAudioAndImageFiles.
  ///
  /// In en, this message translates to:
  /// **'Access Audio & Image Files'**
  String get accessAudioAndImageFiles;

  /// No description provided for @accessAudioSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required to index audio tracks and scan local cover images (artist.jpg / cover.jpg) on your device.'**
  String get accessAudioSubtitle;

  /// No description provided for @albumCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album} other{{count} albums}}'**
  String albumCount(int count);

  /// No description provided for @albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albums;

  /// No description provided for @allPermissionsGranted.
  ///
  /// In en, this message translates to:
  /// **'All Permissions Granted'**
  String get allPermissionsGranted;

  /// No description provided for @alreadyOnLatest.
  ///
  /// In en, this message translates to:
  /// **'You are already on the latest version.'**
  String get alreadyOnLatest;

  /// No description provided for @amoledDark.
  ///
  /// In en, this message translates to:
  /// **'AMOLED Pure Black'**
  String get amoledDark;

  /// No description provided for @amoledDarkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use pitch black backgrounds in dark mode instead of dark gray'**
  String get amoledDarkSubtitle;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// App title
  ///
  /// In en, this message translates to:
  /// **'Sonora'**
  String get appTitle;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Theme'**
  String get appearanceSettings;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, colors, visualizer, local images'**
  String get appearanceSubtitle;

  /// No description provided for @artistCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 artist} other{{count} artists}}'**
  String artistCount(int count);

  /// No description provided for @artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artists;

  /// No description provided for @autoCheckUpdates.
  ///
  /// In en, this message translates to:
  /// **'Automatically Check for Updates'**
  String get autoCheckUpdates;

  /// No description provided for @autoCheckUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check GitHub for releases every time the app opens'**
  String get autoCheckUpdatesSubtitle;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cancelTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel Timer'**
  String get cancelTimer;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @changeCover.
  ///
  /// In en, this message translates to:
  /// **'Change Cover'**
  String get changeCover;

  /// No description provided for @changeFolder.
  ///
  /// In en, this message translates to:
  /// **'Change Folder'**
  String get changeFolder;

  /// No description provided for @changelog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// No description provided for @changelogLabel.
  ///
  /// In en, this message translates to:
  /// **'Changelog:'**
  String get changelogLabel;

  /// No description provided for @changelogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View what\'s new'**
  String get changelogSubtitle;

  /// No description provided for @changelogTitle.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelogTitle;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @checkForUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check GitHub for a new release'**
  String get checkForUpdatesSubtitle;

  /// No description provided for @chooseMusicFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose the primary folder containing your audio tracks (MP3, FLAC, M4A, etc.) to build your initial library database.'**
  String get chooseMusicFolder;

  /// No description provided for @chooseTheme.
  ///
  /// In en, this message translates to:
  /// **'Choose Theme'**
  String get chooseTheme;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @communityAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Community & Support'**
  String get communityAndSupport;

  /// No description provided for @configurePermissions.
  ///
  /// In en, this message translates to:
  /// **'Configure Permissions'**
  String get configurePermissions;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @createPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Create a playlist'**
  String get createPlaylist;

  /// No description provided for @customDuration.
  ///
  /// In en, this message translates to:
  /// **'Custom Duration...'**
  String get customDuration;

  /// No description provided for @customSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Custom Sleep Timer'**
  String get customSleepTimer;

  /// No description provided for @dangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger Zone'**
  String get dangerZone;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @darkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always use dark theme'**
  String get darkSubtitle;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @dateCreated.
  ///
  /// In en, this message translates to:
  /// **'Date Created'**
  String get dateCreated;

  /// No description provided for @dateModified.
  ///
  /// In en, this message translates to:
  /// **'Date Modified'**
  String get dateModified;

  /// No description provided for @defaultAppColor.
  ///
  /// In en, this message translates to:
  /// **'Default App Color'**
  String get defaultAppColor;

  /// No description provided for @defaultSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Default Sleep Timer'**
  String get defaultSleepTimer;

  /// No description provided for @defaultSleepTimerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default duration selected when opening the sleep timer'**
  String get defaultSleepTimerSubtitle;

  /// No description provided for @defaultStartPage.
  ///
  /// In en, this message translates to:
  /// **'Default Start Page'**
  String get defaultStartPage;

  /// No description provided for @defaultStartPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Page to show when the app starts'**
  String get defaultStartPageSubtitle;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deletePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist'**
  String get deletePlaylist;

  /// No description provided for @deletePlaylistConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String deletePlaylistConfirmMessage(String name);

  /// No description provided for @deletePlaylistConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Playlist?'**
  String get deletePlaylistConfirmTitle;

  /// No description provided for @developerProfile.
  ///
  /// In en, this message translates to:
  /// **'Developer Profile'**
  String get developerProfile;

  /// No description provided for @developerProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check out yurtemre7 on GitHub'**
  String get developerProfileSubtitle;

  /// No description provided for @displayedAs.
  ///
  /// In en, this message translates to:
  /// **'Displayed As:'**
  String get displayedAs;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @dynamicTheme.
  ///
  /// In en, this message translates to:
  /// **'Dynamic Theme (Material You)'**
  String get dynamicTheme;

  /// No description provided for @dynamicThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically theme the app using active album art'**
  String get dynamicThemeSubtitle;

  /// No description provided for @enterDurationHint.
  ///
  /// In en, this message translates to:
  /// **'Enter duration'**
  String get enterDurationHint;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter Your Name'**
  String get enterYourName;

  /// No description provided for @failedToLoadChangelog.
  ///
  /// In en, this message translates to:
  /// **'Failed to load changelog.'**
  String get failedToLoadChangelog;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @fileSize.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get fileSize;

  /// No description provided for @filterTitleArtist.
  ///
  /// In en, this message translates to:
  /// **'Remove artist from titles'**
  String get filterTitleArtist;

  /// No description provided for @filterTitleArtistSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hides \"Artist - \" from the beginning of song titles.'**
  String get filterTitleArtistSubtitle;

  /// No description provided for @filterTitleFeatures.
  ///
  /// In en, this message translates to:
  /// **'Remove (feat.) from titles'**
  String get filterTitleFeatures;

  /// No description provided for @filterTitleFeaturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hides featured artists from the song title if present.'**
  String get filterTitleFeaturesSubtitle;

  /// No description provided for @formattingSettings.
  ///
  /// In en, this message translates to:
  /// **'Title & Metadata Formatting'**
  String get formattingSettings;

  /// No description provided for @formattingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure how song titles are displayed'**
  String get formattingSubtitle;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String goodAfternoon(String name);

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String goodEvening(String name);

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String goodMorning(String name);

  /// No description provided for @infoSettings.
  ///
  /// In en, this message translates to:
  /// **'Info & Support'**
  String get infoSettings;

  /// No description provided for @infoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'About, updates, changelog, danger zone'**
  String get infoSubtitle;

  /// No description provided for @keepPlayingOnClose.
  ///
  /// In en, this message translates to:
  /// **'Keep playing on app close'**
  String get keepPlayingOnClose;

  /// No description provided for @keepPlayingOnCloseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep playing music in the background when swiped away'**
  String get keepPlayingOnCloseSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// No description provided for @lastSync.
  ///
  /// In en, this message translates to:
  /// **'Last Sync'**
  String get lastSync;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @libraryFormatting.
  ///
  /// In en, this message translates to:
  /// **'Library Formatting'**
  String get libraryFormatting;

  /// No description provided for @librarySync.
  ///
  /// In en, this message translates to:
  /// **'Library Sync'**
  String get librarySync;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// No description provided for @licensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open source licenses'**
  String get licensesSubtitle;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @lightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Always use light theme'**
  String get lightSubtitle;

  /// No description provided for @listeningStatistics.
  ///
  /// In en, this message translates to:
  /// **'Listening Statistics'**
  String get listeningStatistics;

  /// No description provided for @lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyrics;

  /// No description provided for @mfx.
  ///
  /// In en, this message translates to:
  /// **'MFX'**
  String get mfx;

  /// No description provided for @mfxBassBoosted.
  ///
  /// In en, this message translates to:
  /// **'Bass Boosted'**
  String get mfxBassBoosted;

  /// No description provided for @mfxLoFi.
  ///
  /// In en, this message translates to:
  /// **'Lo-Fi / Vintage Room'**
  String get mfxLoFi;

  /// No description provided for @mfxResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset All Effects'**
  String get mfxResetAll;

  /// No description provided for @mfxWarmth.
  ///
  /// In en, this message translates to:
  /// **'Warmth (Reverb)'**
  String get mfxWarmth;

  /// No description provided for @minuteAbbr.
  ///
  /// In en, this message translates to:
  /// **'{min} min'**
  String minuteAbbr(int min);

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// No description provided for @neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get neverSynced;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @noAlbumsFound.
  ///
  /// In en, this message translates to:
  /// **'No albums found'**
  String get noAlbumsFound;

  /// No description provided for @noArtistsFound.
  ///
  /// In en, this message translates to:
  /// **'No artists found'**
  String get noArtistsFound;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get noFavoritesYet;

  /// No description provided for @noMatchingAlbumsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching albums found'**
  String get noMatchingAlbumsFound;

  /// No description provided for @noMatchingArtistsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching artists found'**
  String get noMatchingArtistsFound;

  /// No description provided for @noMatchingPlaylistsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching playlists found'**
  String get noMatchingPlaylistsFound;

  /// No description provided for @noMatchingSongsFound.
  ///
  /// In en, this message translates to:
  /// **'No matching songs found'**
  String get noMatchingSongsFound;

  /// No description provided for @noMusicFilesFound.
  ///
  /// In en, this message translates to:
  /// **'No music files found'**
  String get noMusicFilesFound;

  /// No description provided for @noPlaylistsFound.
  ///
  /// In en, this message translates to:
  /// **'No playlists found'**
  String get noPlaylistsFound;

  /// No description provided for @noSongsFound.
  ///
  /// In en, this message translates to:
  /// **'No songs found'**
  String get noSongsFound;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @onboardingDescription.
  ///
  /// In en, this message translates to:
  /// **'A premium offline music experience built with beautiful Material 3 Expressive elements.\n\nEnjoy fluid, stutter-free playback and fast background syncing.'**
  String get onboardingDescription;

  /// No description provided for @openGithubReleases.
  ///
  /// In en, this message translates to:
  /// **'Open GitHub Releases'**
  String get openGithubReleases;

  /// No description provided for @originalMetadata.
  ///
  /// In en, this message translates to:
  /// **'Original Metadata:'**
  String get originalMetadata;

  /// No description provided for @pauseOnDuck.
  ///
  /// In en, this message translates to:
  /// **'Pause on notifications'**
  String get pauseOnDuck;

  /// No description provided for @pauseOnDuckSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pause music instead of lowering volume when a notification arrives'**
  String get pauseOnDuckSubtitle;

  /// No description provided for @permissionsExplained.
  ///
  /// In en, this message translates to:
  /// **'Permissions Explained'**
  String get permissionsExplained;

  /// No description provided for @permissionsExplanation.
  ///
  /// In en, this message translates to:
  /// **'To play and control your music, Sonora needs runtime authorization permissions from your device.'**
  String get permissionsExplanation;

  /// No description provided for @permissionsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Permissions Needed'**
  String get permissionsNeeded;

  /// No description provided for @personalization.
  ///
  /// In en, this message translates to:
  /// **'Personalization'**
  String get personalization;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @playAll.
  ///
  /// In en, this message translates to:
  /// **'Play All'**
  String get playAll;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @playbackSettings.
  ///
  /// In en, this message translates to:
  /// **'Playback & Audio'**
  String get playbackSettings;

  /// No description provided for @playbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer, start page, background play'**
  String get playbackSubtitle;

  /// No description provided for @playlistCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 playlist} other{{count} playlists}}'**
  String playlistCount(int count);

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist name'**
  String get playlistName;

  /// No description provided for @playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlists;

  /// No description provided for @preferLocalArtistImages.
  ///
  /// In en, this message translates to:
  /// **'Prefer Local Artist Images'**
  String get preferLocalArtistImages;

  /// No description provided for @preferLocalArtistImagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use local artist.jpg files from your music folders when available'**
  String get preferLocalArtistImagesSubtitle;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @privacyCardDataContent.
  ///
  /// In en, this message translates to:
  /// **'This app operates entirely offline and communicates with no servers, with the exception of checking GitHub for app updates. All of your library statistics, preferences, and playtime data stay strictly on your device and are never sent anywhere. \n\nYou can trust that your listening habits remain private.'**
  String get privacyCardDataContent;

  /// No description provided for @privacyCardDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Data is Yours'**
  String get privacyCardDataTitle;

  /// No description provided for @privacyCardDeleteDataContent.
  ///
  /// In en, this message translates to:
  /// **'You have full control. You can wipe all app settings, statistics, and caches instantly at any time from the Danger Zone located at the bottom of the Info & Support tab.'**
  String get privacyCardDeleteDataContent;

  /// No description provided for @privacyCardDeleteDataTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete All Data'**
  String get privacyCardDeleteDataTitle;

  /// No description provided for @privacyCardInternetContent.
  ///
  /// In en, this message translates to:
  /// **'Only used to fetch the latest release version and changelog from GitHub to notify you of available updates.'**
  String get privacyCardInternetContent;

  /// No description provided for @privacyCardInternetTitle.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get privacyCardInternetTitle;

  /// No description provided for @privacyCardNotificationsContent.
  ///
  /// In en, this message translates to:
  /// **'Used to display the media player controls in your notification shade and lock screen. A foreground service is required to keep the music playing continuously in the background when the app is closed.'**
  String get privacyCardNotificationsContent;

  /// No description provided for @privacyCardNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications & Foreground Service'**
  String get privacyCardNotificationsTitle;

  /// No description provided for @privacyCardStorageContent.
  ///
  /// In en, this message translates to:
  /// **'Used to scan your selected music folder for audio tracks and local artist/album artwork (e.g., artist.jpg or cover.png).\n\nTransparent Privacy Guarantee: Although Android prompts for \"Photos & Media\" access, Sonora strictly scans files inside your designated music directory. We NEVER read, inspect, or access your personal photo gallery, camera roll, or private images.'**
  String get privacyCardStorageContent;

  /// No description provided for @privacyCardStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage, Audio & Cover Images'**
  String get privacyCardStorageTitle;

  /// No description provided for @privacyCardWakeLockContent.
  ///
  /// In en, this message translates to:
  /// **'Prevents your device from sleeping and abruptly stopping the music playback while you are listening.'**
  String get privacyCardWakeLockContent;

  /// No description provided for @privacyCardWakeLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Wake Lock'**
  String get privacyCardWakeLockTitle;

  /// No description provided for @privacyPermissions.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Permissions'**
  String get privacyPermissions;

  /// No description provided for @privacySettings.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Permissions'**
  String get privacySettings;

  /// No description provided for @privacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Data management and required permissions'**
  String get privacySubtitle;

  /// No description provided for @queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queueEmpty;

  /// No description provided for @rateLimitMessage.
  ///
  /// In en, this message translates to:
  /// **'GitHub API rate limit (60 requests/hour for anonymous requests) has been reached.\n\nPlease open the GitHub repository directly to check for new releases.'**
  String get rateLimitMessage;

  /// No description provided for @rateLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Rate Limit Exceeded'**
  String get rateLimitTitle;

  /// No description provided for @removeCover.
  ///
  /// In en, this message translates to:
  /// **'Remove Cover'**
  String get removeCover;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renamePlaylist.
  ///
  /// In en, this message translates to:
  /// **'Rename Playlist'**
  String get renamePlaylist;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @resetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetAll;

  /// No description provided for @resetApplication.
  ///
  /// In en, this message translates to:
  /// **'Reset Application'**
  String get resetApplication;

  /// No description provided for @resetApplicationConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all imported audio files and clear your library. This cannot be undone.'**
  String get resetApplicationConfirmMessage;

  /// No description provided for @resetApplicationConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Application?'**
  String get resetApplicationConfirmTitle;

  /// No description provided for @resetApplicationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hold for 3 seconds to wipe all data.'**
  String get resetApplicationSubtitle;

  /// No description provided for @resetStatistics.
  ///
  /// In en, this message translates to:
  /// **'Reset Statistics'**
  String get resetStatistics;

  /// No description provided for @resetStatisticsConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your listening statistics, including total time, play counts, and top charts. This cannot be undone.'**
  String get resetStatisticsConfirmMessage;

  /// No description provided for @resetStatisticsConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Statistics?'**
  String get resetStatisticsConfirmTitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @searchAlbumsHint.
  ///
  /// In en, this message translates to:
  /// **'Search albums...'**
  String get searchAlbumsHint;

  /// No description provided for @searchArtistsHint.
  ///
  /// In en, this message translates to:
  /// **'Search artists...'**
  String get searchArtistsHint;

  /// No description provided for @searchPlaylistsHint.
  ///
  /// In en, this message translates to:
  /// **'Search playlists...'**
  String get searchPlaylistsHint;

  /// No description provided for @searchSongsHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists...'**
  String get searchSongsHint;

  /// No description provided for @selectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Folder'**
  String get selectFolder;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @selectedDirectory.
  ///
  /// In en, this message translates to:
  /// **'Selected Directory:'**
  String get selectedDirectory;

  /// No description provided for @setMusicDirectory.
  ///
  /// In en, this message translates to:
  /// **'Set Music Directory'**
  String get setMusicDirectory;

  /// No description provided for @setSyncFolder.
  ///
  /// In en, this message translates to:
  /// **'Set Sync Folder'**
  String get setSyncFolder;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @setupMusicDirectory.
  ///
  /// In en, this message translates to:
  /// **'Setup Music Directory'**
  String get setupMusicDirectory;

  /// No description provided for @showAudioVisualizer.
  ///
  /// In en, this message translates to:
  /// **'Show Audio Visualizer'**
  String get showAudioVisualizer;

  /// No description provided for @showAudioVisualizerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Animate audio wave visualizer inside player screen'**
  String get showAudioVisualizerSubtitle;

  /// No description provided for @showNotifications.
  ///
  /// In en, this message translates to:
  /// **'Show Notifications'**
  String get showNotifications;

  /// No description provided for @showNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Required to show lockscreen & notification shade media playback controls.'**
  String get showNotificationsSubtitle;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @shuffleAll.
  ///
  /// In en, this message translates to:
  /// **'Shuffle All'**
  String get shuffleAll;

  /// No description provided for @shufflePlay.
  ///
  /// In en, this message translates to:
  /// **'Shuffle Play'**
  String get shufflePlay;

  /// No description provided for @songCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String songCount(int count);

  /// No description provided for @songs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get songs;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @sortAlbumsBy.
  ///
  /// In en, this message translates to:
  /// **'Sort Albums By'**
  String get sortAlbumsBy;

  /// No description provided for @sortArtistsBy.
  ///
  /// In en, this message translates to:
  /// **'Sort Artists By'**
  String get sortArtistsBy;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Sort Ascending'**
  String get sortAscending;

  /// No description provided for @sortByAlbumCount.
  ///
  /// In en, this message translates to:
  /// **'Album Count'**
  String get sortByAlbumCount;

  /// No description provided for @sortByAlbumName.
  ///
  /// In en, this message translates to:
  /// **'Album Name'**
  String get sortByAlbumName;

  /// No description provided for @sortByArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get sortByArtist;

  /// No description provided for @sortByArtistName.
  ///
  /// In en, this message translates to:
  /// **'Artist Name'**
  String get sortByArtistName;

  /// No description provided for @sortByDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get sortByDuration;

  /// No description provided for @sortByName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sortByName;

  /// No description provided for @sortByPlaylistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get sortByPlaylistName;

  /// No description provided for @sortByRecentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently Added'**
  String get sortByRecentlyAdded;

  /// No description provided for @sortBySongCount.
  ///
  /// In en, this message translates to:
  /// **'Song Count'**
  String get sortBySongCount;

  /// No description provided for @sortByTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortByTitle;

  /// No description provided for @sortByTrackCount.
  ///
  /// In en, this message translates to:
  /// **'Track Count'**
  String get sortByTrackCount;

  /// No description provided for @sortPlaylistsBy.
  ///
  /// In en, this message translates to:
  /// **'Sort Playlists By'**
  String get sortPlaylistsBy;

  /// No description provided for @sortSongsBy.
  ///
  /// In en, this message translates to:
  /// **'Sort Songs By'**
  String get sortSongsBy;

  /// No description provided for @sortSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your sorting preference will be saved per tab and automatically applied on next startup.'**
  String get sortSubtitle;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source Code'**
  String get sourceCode;

  /// No description provided for @sourceCodeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View the GitHub repository'**
  String get sourceCodeSubtitle;

  /// No description provided for @startTimer.
  ///
  /// In en, this message translates to:
  /// **'Start Timer'**
  String get startTimer;

  /// No description provided for @stats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// No description provided for @syncExplanation.
  ///
  /// In en, this message translates to:
  /// **'Sonora plays your files locally and offline. When you copy new tracks into this folder, run a sync below to add them to your library.'**
  String get syncExplanation;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get systemDefault;

  /// No description provided for @systemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follows your device theme'**
  String get systemSubtitle;

  /// No description provided for @telegramContact.
  ///
  /// In en, this message translates to:
  /// **'Telegram Contact'**
  String get telegramContact;

  /// No description provided for @telegramContactSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reach out via @emredev'**
  String get telegramContactSubtitle;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @timerDuration.
  ///
  /// In en, this message translates to:
  /// **'Timer Duration'**
  String get timerDuration;

  /// No description provided for @titleFilters.
  ///
  /// In en, this message translates to:
  /// **'Title Filters'**
  String get titleFilters;

  /// No description provided for @trackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String trackCount(int count);

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update Available'**
  String get updateAvailable;

  /// No description provided for @updateAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is now available!'**
  String updateAvailableMessage(String version);

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check for updates. Check your internet connection.'**
  String get updateCheckFailed;

  /// No description provided for @useGreetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Use Greeting Title'**
  String get useGreetingTitle;

  /// No description provided for @useGreetingTitleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show a time-based greeting on the home screen instead of the app name'**
  String get useGreetingTitleSubtitle;

  /// No description provided for @viewStatistics.
  ///
  /// In en, this message translates to:
  /// **'View Statistics'**
  String get viewStatistics;

  /// No description provided for @viewStatisticsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See your playback history and stats'**
  String get viewStatisticsSubtitle;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @welcomeToSonora.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Sonora'**
  String get welcomeToSonora;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your Name'**
  String get yourName;

  /// No description provided for @yourNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Your Name (Optional)'**
  String get yourNameOptional;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
