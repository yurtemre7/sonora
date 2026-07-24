// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get aboutSonora => 'Sonoraについて';

  @override
  String get accessAudioAndImageFiles => '音声ファイルと画像ファイルへのアクセス';

  @override
  String get accessAudioSubtitle =>
      '音声トラックのインデックス作成と、ローカルのカバー画像（artist.jpg / cover.jpg）のスキャンに必要です。';

  @override
  String get activeSyncLocation => '現在の同期先';

  @override
  String get addToPlaylist => 'プレイリストに追加';

  @override
  String get addToQueue => 'キューに追加';

  @override
  String albumCount(int count) {
    return '$count件のアルバム';
  }

  @override
  String get albums => 'アルバム';

  @override
  String get allPermissionsGranted => 'すべての権限が許可されました';

  @override
  String get alreadyOnLatest => 'すでに最新バージョンです。';

  @override
  String get amoledDark => 'AMOLEDピュアブラック';

  @override
  String get amoledDarkSubtitle => 'ダークモード時に、ダークグレーではなく完全な黒背景を使用します';

  @override
  String get appDescription =>
      'FlutterとMaterial 3 Expressiveデザインで構築された、Android向けの美しいローカル音楽プレーヤーです。';

  @override
  String get appInfo => 'アプリ情報';

  @override
  String get appLanguage => 'アプリの言語';

  @override
  String get appTitle => 'Sonora';

  @override
  String get appearance => '外観';

  @override
  String get appearanceSettings => '外観とテーマ';

  @override
  String get appearanceSubtitle => 'テーマ、カラー、ビジュアライザー、ローカル画像';

  @override
  String artistCount(int count) {
    return '$count人のアーティスト';
  }

  @override
  String get artists => 'アーティスト';

  @override
  String get autoCheckUpdates => '更新を自動確認';

  @override
  String get autoCheckUpdatesSubtitle => 'アプリ起動時にGitHubで新しいリリースを確認します';

  @override
  String get back => '戻る';

  @override
  String get cancel => 'キャンセル';

  @override
  String get cancelTimer => 'タイマーをキャンセル';

  @override
  String get change => '変更';

  @override
  String get changeCover => 'カバーを変更';

  @override
  String get changeFolder => 'フォルダを変更';

  @override
  String get changelog => '更新履歴';

  @override
  String get changelogLabel => '更新履歴:';

  @override
  String get changelogSubtitle => '新機能を確認';

  @override
  String get changelogTitle => '更新履歴';

  @override
  String get checkForUpdates => '更新を確認';

  @override
  String get checkForUpdatesSubtitle => 'GitHubで新しいリリースを確認します';

  @override
  String get chooseMusicFolder =>
      '初回ライブラリを作成するため、音声ファイル（MP3、FLAC、M4Aなど）が含まれているメインフォルダを選択してください。';

  @override
  String get chooseSquareImage => '最適な表示のため、正方形の画像を選択してください。';

  @override
  String get chooseTheme => 'テーマを選択';

  @override
  String get close => '閉じる';

  @override
  String get communityAndSupport => 'コミュニティとサポート';

  @override
  String get configurePermissions => '権限を設定';

  @override
  String get create => '作成';

  @override
  String get createPlaylist => 'プレイリストを作成';

  @override
  String get customDuration => 'カスタム時間...';

  @override
  String get customSleepTimer => 'カスタムスリープタイマー';

  @override
  String get customSpeed => 'カスタム速度';

  @override
  String get dangerZone => '危険な操作';

  @override
  String get dark => 'ダーク';

  @override
  String get darkSubtitle => '常にダークテーマを使用します';

  @override
  String get dataManagement => 'データ管理';

  @override
  String get dateCreated => '作成日';

  @override
  String get dateModified => '更新日';

  @override
  String get defaultAppColor => 'デフォルトのアプリカラー';

  @override
  String get defaultSleepTimer => 'デフォルトのスリープタイマー';

  @override
  String get defaultSleepTimerSubtitle => 'スリープタイマーを開いたときに最初に選択される時間です';

  @override
  String get defaultStartPage => 'デフォルトの開始ページ';

  @override
  String get defaultStartPageSubtitle => 'アプリ起動時に表示するページです';

  @override
  String get delete => '削除';

  @override
  String get deletePlaylist => 'プレイリストを削除';

  @override
  String deletePlaylistConfirmMessage(String name) {
    return '「$name」を削除しますか？ この操作は元に戻せません。';
  }

  @override
  String get deletePlaylistConfirmTitle => 'プレイリストを削除しますか？';

  @override
  String get description => '説明';

  @override
  String get developerProfile => '開発者プロフィール';

  @override
  String get developerProfileSubtitle => 'GitHubでyurtemre7を見る';

  @override
  String get disableShuffle => 'シャッフルをオフ';

  @override
  String get displayedAs => '表示形式:';

  @override
  String get download => 'ダウンロード';

  @override
  String get dynamicTheme => 'ダイナミックテーマ（Material You）';

  @override
  String get dynamicThemeSubtitle => '現在のアルバムアートに合わせてアプリのテーマを自動調整します';

  @override
  String get editDescription => '説明を編集';

  @override
  String get enableShuffle => 'シャッフルをオン';

  @override
  String get enterDurationHint => '時間を入力';

  @override
  String get enterYourName => '名前を入力';

  @override
  String get experimental => '実験的';

  @override
  String get exportToM3u => 'M3Uにエクスポート';

  @override
  String exportedPlaylist(String name) {
    return 'プレイリストをエクスポートしました: $name';
  }

  @override
  String get failedToExport => 'エクスポートに失敗しました';

  @override
  String get failedToLoadChangelog => '更新履歴を読み込めませんでした。';

  @override
  String get failedToSelectDirectory => 'フォルダを選択できませんでした。もう一度お試しください。';

  @override
  String get favoriteRemove => 'お気に入りから削除';

  @override
  String get favoriteSong => 'お気に入りの曲';

  @override
  String get favorites => 'お気に入り';

  @override
  String get fileSize => 'ファイルサイズ';

  @override
  String get filterTitleArtist => 'タイトル先頭のアーティスト名を削除';

  @override
  String get filterTitleArtistSubtitle => '曲名の先頭にある「Artist - 」を非表示にします。';

  @override
  String get filterTitleFeatures => 'タイトル内の（feat.）を削除';

  @override
  String get filterTitleFeaturesSubtitle => '曲名に含まれるフィーチャリング情報を非表示にします。';

  @override
  String get formattingSettings => 'タイトルとメタデータの表示形式';

  @override
  String get formattingSubtitle => '曲名の表示方法を設定します';

  @override
  String get getStarted => 'はじめる';

  @override
  String goodAfternoon(String name) {
    return '$nameさん、こんにちは';
  }

  @override
  String goodEvening(String name) {
    return '$nameさん、こんばんは';
  }

  @override
  String goodMorning(String name) {
    return '$nameさん、おはようございます';
  }

  @override
  String get infoSettings => '情報とサポート';

  @override
  String get infoSubtitle => 'アプリ情報、更新、更新履歴、危険な操作';

  @override
  String get keepPlayingOnClose => 'アプリ終了後も再生を継続';

  @override
  String get keepPlayingOnCloseSubtitle => 'アプリをスワイプして閉じても、バックグラウンドで再生を続けます';

  @override
  String get language => '言語';

  @override
  String get languageEnglish => '英語';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSystem => 'システムのデフォルト';

  @override
  String get lastSync => '最終同期';

  @override
  String get later => 'あとで';

  @override
  String get libraryFormatting => 'ライブラリの表示形式';

  @override
  String get librarySync => 'ライブラリ同期';

  @override
  String get licenses => 'ライセンス';

  @override
  String get licensesSubtitle => 'オープンソースライセンス';

  @override
  String get light => 'ライト';

  @override
  String get lightSubtitle => '常にライトテーマを使用します';

  @override
  String get listeningStatistics => '再生統計';

  @override
  String get lyrics => '歌詞';

  @override
  String get lyricsCaps => '歌詞';

  @override
  String get madeWithLove => 'yurtemreが❤️を込めて制作';

  @override
  String get mfx => 'MFX';

  @override
  String get mfxBassBoosted => '低音強調';

  @override
  String get mfxBassBoostedSubtitle => '低音域を強くブーストします（+80%）';

  @override
  String get mfxLoFi => 'Lo‑Fi / ヴィンテージルーム';

  @override
  String get mfxLoFiSubtitle => '高域を大きくカットするフィルターです';

  @override
  String get mfxResetAll => 'すべてのエフェクトをリセット';

  @override
  String get mfxWarmth => '暖かみ（リバーブ）';

  @override
  String get mfxWarmthSubtitle => 'EQで再現します（低音ブースト、高域カット）';

  @override
  String minuteAbbr(int min) {
    return '$min分';
  }

  @override
  String get minutes => '分';

  @override
  String get musicEffects => '音響エフェクト';

  @override
  String get neverSynced => '一度も同期していません';

  @override
  String get next => '次へ';

  @override
  String get nextTooltip => '次へ';

  @override
  String get noAlbumsFound => 'アルバムが見つかりません';

  @override
  String get noArtistsFound => 'アーティストが見つかりません';

  @override
  String get noFavoritesYet => 'お気に入りはまだありません';

  @override
  String get noLyricsAvailable => '利用可能な歌詞はありません';

  @override
  String get noLyricsFound => '歌詞が見つかりません';

  @override
  String get noMatchingAlbumsFound => '一致するアルバムが見つかりません';

  @override
  String get noMatchingArtistsFound => '一致するアーティストが見つかりません';

  @override
  String get noMatchingPlaylistsFound => '一致するプレイリストが見つかりません';

  @override
  String get noMatchingSongsFound => '一致する曲が見つかりません';

  @override
  String get noMusicFilesFound => '音楽ファイルが見つかりません';

  @override
  String get noPlaylistsFound => 'プレイリストが見つかりません';

  @override
  String get noRelatedSongs => '関連する曲はありません';

  @override
  String get noSongsFound => '曲が見つかりません';

  @override
  String get ok => 'OK';

  @override
  String get onboardingDescription =>
      '美しいMaterial 3 Expressive要素で構築された、プレミアムなオフライン音楽体験です。\n\n滑らかで途切れのない再生と、高速なバックグラウンド同期をお楽しみください。';

  @override
  String get openGithubReleases => 'GitHub Releasesを開く';

  @override
  String get originalMetadata => '元のメタデータ:';

  @override
  String get pauseOnDuck => '通知時に一時停止';

  @override
  String get pauseOnDuckSubtitle => '通知が届いたとき、音量を下げる代わりに再生を一時停止します';

  @override
  String get pauseTooltip => '一時停止';

  @override
  String get permissionsExplained => '権限の説明';

  @override
  String get permissionsExplanation => '音楽を再生・操作するために、Sonoraは端末の実行時権限を必要とします。';

  @override
  String get permissionsGrantedSuccess => '権限の設定が完了しました！';

  @override
  String get permissionsNeeded => '必要な権限';

  @override
  String get personalization => 'パーソナライズ';

  @override
  String get placeLrcFile =>
      '歌詞を読み込むには、音声ファイルと同じ名前の .lrc または .txt ファイルを隣に配置してください。';

  @override
  String get play => '再生';

  @override
  String get playAll => 'すべて再生';

  @override
  String get playNext => '次に再生';

  @override
  String get playTooltip => '再生';

  @override
  String get playback => '再生';

  @override
  String get playbackSettings => '再生と音声';

  @override
  String get playbackSubtitle => 'スリープタイマー、開始ページ、バックグラウンド再生';

  @override
  String playlistCount(int count) {
    return '$count件のプレイリスト';
  }

  @override
  String get playlistName => 'プレイリスト名';

  @override
  String get playlists => 'プレイリスト';

  @override
  String get plusOneMin => '+1分';

  @override
  String get preferLocalArtistImages => 'ローカルのアーティスト画像を優先';

  @override
  String get preferLocalArtistImagesSubtitle =>
      '利用可能な場合、音楽フォルダ内の artist.jpg を優先して使用します';

  @override
  String get presetSpeedAndPitch => '速度とピッチのプリセット';

  @override
  String get preview => 'プレビュー';

  @override
  String get previousTooltip => '前へ';

  @override
  String get privacyCardDataContent =>
      'このアプリは完全にオフラインで動作し、アプリ更新の確認のためにGitHubへアクセスする場合を除き、いかなるサーバーとも通信しません。ライブラリ統計、設定、再生時間データはすべて端末内にのみ保存され、外部へ送信されることはありません。\n\nあなたの再生履歴やリスニング習慣はプライベートに保たれます。';

  @override
  String get privacyCardDataTitle => 'データはあなたのものです';

  @override
  String get privacyCardDeleteDataContent =>
      'すべてのデータは自分で管理できます。情報とサポートタブの最下部にある危険な操作から、アプリ設定、統計、キャッシュをいつでもすぐに削除できます。';

  @override
  String get privacyCardDeleteDataTitle => 'すべてのデータを削除';

  @override
  String get privacyCardInternetContent =>
      '利用可能な更新を通知するため、GitHubから最新リリースのバージョンと更新履歴を取得する目的でのみ使用されます。';

  @override
  String get privacyCardInternetTitle => 'インターネット';

  @override
  String get privacyCardNotificationsContent =>
      '通知シェードとロック画面にメディアプレーヤーの操作を表示するために使用されます。アプリを閉じてもバックグラウンドで音楽を継続再生するには、フォアグラウンドサービスが必要です。';

  @override
  String get privacyCardNotificationsTitle => '通知とフォアグラウンドサービス';

  @override
  String get privacyCardStorageContent =>
      '選択した音楽フォルダ内の音声トラックと、ローカルのアーティスト／アルバムアートワーク（例: artist.jpg や cover.png）をスキャンするために使用されます。\n\n明確なプライバシー保証: Androidでは「写真とメディア」へのアクセス許可が表示されますが、Sonoraがスキャンするのは指定された音楽ディレクトリ内のファイルに限られます。個人の写真ギャラリー、カメラロール、プライベート画像を読み取ったり、調べたり、アクセスしたりすることは決してありません。';

  @override
  String get privacyCardStorageTitle => 'ストレージ、音声、カバー画像';

  @override
  String get privacyCardWakeLockContent => '再生中に端末がスリープして、音楽再生が突然停止しないようにします。';

  @override
  String get privacyCardWakeLockTitle => 'Wake Lock';

  @override
  String get privacyPermissions => 'プライバシーと権限';

  @override
  String get privacySettings => 'プライバシーと権限';

  @override
  String get privacySubtitle => 'データ管理と必要な権限';

  @override
  String get queue => 'キュー';

  @override
  String get queueEmpty => 'キューは空です';

  @override
  String get queueIsEmpty => 'キューは空です';

  @override
  String queueNOfM(int current, int total) {
    return 'キュー（$current / $total）';
  }

  @override
  String queueXOfY(int current, int total) {
    return 'キュー（$current / $total）';
  }

  @override
  String get rateLimitMessage =>
      'GitHub APIのレート制限（匿名リクエストは1時間あたり60回）に達しました。\n\n新しいリリースを確認するには、GitHubリポジトリを直接開いてください。';

  @override
  String get rateLimitTitle => 'レート制限を超過しました';

  @override
  String get refresh => '更新';

  @override
  String get related => '関連';

  @override
  String get relatedCaps => '関連';

  @override
  String get removeCover => 'カバーを削除';

  @override
  String get removeFromPlaylist => 'プレイリストから削除';

  @override
  String get rename => '名前を変更';

  @override
  String get renamePlaylist => 'プレイリスト名を変更';

  @override
  String get repeatAll => 'すべてリピート';

  @override
  String get repeatOff => 'リピートオフ';

  @override
  String get repeatOne => '1曲リピート';

  @override
  String get reset => 'リセット';

  @override
  String get resetAll => 'リセット';

  @override
  String get resetApplication => 'アプリをリセット';

  @override
  String get resetApplicationConfirmMessage =>
      '取り込まれたすべての音声ファイルが完全に削除され、ライブラリが消去されます。この操作は元に戻せません。';

  @override
  String get resetApplicationConfirmTitle => 'アプリをリセットしますか？';

  @override
  String get resetApplicationSubtitle => '3秒間長押しすると、すべてのデータを削除します。';

  @override
  String get resetSpeed => '1.0xに戻す';

  @override
  String get resetStatistics => '統計をリセット';

  @override
  String get resetStatisticsConfirmMessage =>
      '総再生時間、再生回数、トップチャートを含むすべての再生統計が完全に削除されます。この操作は元に戻せません。';

  @override
  String get resetStatisticsConfirmTitle => '統計をリセットしますか？';

  @override
  String get resetStatisticsTitle => '統計をリセットしますか？';

  @override
  String get resetStatisticsWarning =>
      '総再生時間、再生回数、トップチャートを含むすべての再生統計が完全に削除されます。この操作は元に戻せません。';

  @override
  String get save => '保存';

  @override
  String get saveAsPlaylist => 'プレイリストとして保存';

  @override
  String get saveQueueAsPlaylist => 'キューをプレイリストとして保存';

  @override
  String get searchAlbumsHint => 'アルバムを検索...';

  @override
  String get searchArtistsHint => 'アーティストを検索...';

  @override
  String get searchPlaylistsHint => 'プレイリストを検索...';

  @override
  String get searchSongsHint => '曲名、アーティストを検索...';

  @override
  String get selectFolder => 'フォルダを選択';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get selectedDirectory => '選択したディレクトリ:';

  @override
  String get setMusicDirectory => '音楽ディレクトリを設定';

  @override
  String get setSyncFolder => '同期フォルダを設定';

  @override
  String get settings => '設定';

  @override
  String get setupMusicDirectory => '音楽ディレクトリを設定';

  @override
  String get showAudioVisualizer => '音声ビジュアライザーを表示';

  @override
  String get showAudioVisualizerSubtitle =>
      'プレーヤー画面内で音声波形ビジュアライザーをアニメーション表示します';

  @override
  String get showNotifications => '通知を表示';

  @override
  String get showNotificationsSubtitle =>
      'ロック画面と通知シェードにメディア再生コントロールを表示するために必要です。';

  @override
  String get shuffle => 'シャッフル';

  @override
  String get shuffleAll => 'すべてシャッフル';

  @override
  String get shufflePlay => 'シャッフル再生';

  @override
  String get sleepTimer => 'スリープタイマー';

  @override
  String songCount(int count) {
    return '$count曲';
  }

  @override
  String get songInfo => '曲情報';

  @override
  String get songInformation => '曲の情報';

  @override
  String get songs => '曲';

  @override
  String get sort => '並び替え';

  @override
  String get sortAlbumsBy => 'アルバムの並び替え';

  @override
  String get sortArtistsBy => 'アーティストの並び替え';

  @override
  String get sortAscending => '昇順';

  @override
  String get sortByAlbumCount => 'アルバム数';

  @override
  String get sortByAlbumName => 'アルバム名';

  @override
  String get sortByArtist => 'アーティスト';

  @override
  String get sortByArtistName => 'アーティスト名';

  @override
  String get sortByDateFavorited => 'お気に入り追加日';

  @override
  String get sortByDuration => '再生時間';

  @override
  String get sortByName => '名前';

  @override
  String get sortByPlaylistName => 'プレイリスト名';

  @override
  String get sortByRecentlyAdded => '最近追加した順';

  @override
  String get sortBySongCount => '曲数';

  @override
  String get sortByTitle => 'タイトル';

  @override
  String get sortByTrackCount => 'トラック数';

  @override
  String get sortDescending => '降順';

  @override
  String get sortPlaylistsBy => 'プレイリストの並び替え';

  @override
  String get sortSongsBy => '曲の並び替え';

  @override
  String get sortSubtitle => '並び替え設定はタブごとに保存され、次回起動時に自動で適用されます。';

  @override
  String get sourceCode => 'ソースコード';

  @override
  String get sourceCodeSubtitle => 'GitHubリポジトリを見る';

  @override
  String get startTimer => 'タイマーを開始';

  @override
  String get stats => '統計';

  @override
  String stopInX(String duration) {
    return '$duration後に停止';
  }

  @override
  String syncDuration(String duration) {
    return '${duration}msで完了';
  }

  @override
  String get syncExplanation =>
      'Sonoraはファイルをローカルでオフライン再生します。このフォルダに新しい曲をコピーしたら、下の同期を実行してライブラリに追加してください。';

  @override
  String get syncLibraryDatabase => 'ライブラリデータベースを同期しますか？';

  @override
  String get syncLibraryDatabaseSubtitle =>
      '前回のライブラリ同期から少なくとも1か月が経過しています。Sonoraはオフラインで動作するため、端末のフォルダに新しい音楽ファイルを追加した場合は、今すぐ同期して見つけて再生してください。';

  @override
  String get syncNow => '今すぐ同期';

  @override
  String syncedXSongs(int count, String duration) {
    return '$count曲を同期しました$duration。';
  }

  @override
  String get syncing => '同期中...';

  @override
  String get systemDefault => 'システムのデフォルト';

  @override
  String get systemSubtitle => '端末のテーマに従います';

  @override
  String get telegramContact => 'Telegram連絡先';

  @override
  String get telegramContactSubtitle => '@emredev に連絡';

  @override
  String get themeMode => 'テーマモード';

  @override
  String get timer => 'タイマー';

  @override
  String get timerDuration => 'タイマー時間';

  @override
  String get titleFilters => 'タイトルフィルター';

  @override
  String trackCount(int count) {
    return '$countトラック';
  }

  @override
  String get tryAgain => '再試行';

  @override
  String get upNext => '次に再生';

  @override
  String get upNextCaps => '次に再生';

  @override
  String get updateAvailable => '更新があります';

  @override
  String updateAvailableMessage(String version) {
    return 'バージョン $version が利用可能です！';
  }

  @override
  String get updateCheckFailed => '更新の確認に失敗しました。インターネット接続を確認してください。';

  @override
  String get useGreetingTitle => 'あいさつタイトルを使用';

  @override
  String get useGreetingTitleSubtitle => 'ホーム画面でアプリ名の代わりに時間帯に応じたあいさつを表示します';

  @override
  String version(String version) {
    return 'バージョン $version';
  }

  @override
  String get viewStatistics => '統計を見る';

  @override
  String get viewStatisticsSubtitle => '再生履歴と統計を確認します';

  @override
  String get volume => '音量';

  @override
  String get welcomeToSonora => 'Sonoraへようこそ';

  @override
  String get yesterday => '昨日';

  @override
  String get yourName => 'あなたの名前';

  @override
  String get yourNameOptional => 'あなたの名前（任意）';

  @override
  String get yourOwnPlaylist => '自分のプレイリスト';
}
