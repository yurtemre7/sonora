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
  String get accessAudioAndImageFiles => 'オーディオと画像ファイルへのアクセス';

  @override
  String get accessAudioSubtitle =>
      '音楽ファイルのインデックス作成とローカルカバー画像（artist.jpg / cover.jpg）のスキャンに必要です。';

  @override
  String albumCount(int count) {
    return '$count アルバム';
  }

  @override
  String get albums => 'アルバム';

  @override
  String get allPermissionsGranted => 'すべての権限が許可されました';

  @override
  String get alreadyOnLatest => 'すでに最新バージョンをお使いです。';

  @override
  String get amoledDark => '有機ELピュアブラック';

  @override
  String get amoledDarkSubtitle => 'ダークモード時にダークグレーの代わりに漆黒の背景を使用します';

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
    return '$count アーティスト';
  }

  @override
  String get artists => 'アーティスト';

  @override
  String get autoCheckUpdates => '自動的にアップデートを確認';

  @override
  String get autoCheckUpdatesSubtitle => 'アプリ起動時にGitHubで新バージョンを確認します';

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
  String get changelogLabel => '更新履歴：';

  @override
  String get changelogSubtitle => '新機能を確認';

  @override
  String get changelogTitle => '更新履歴';

  @override
  String get checkForUpdates => 'アップデートを確認';

  @override
  String get checkForUpdatesSubtitle => 'GitHubで新しいリリースを確認します';

  @override
  String get chooseMusicFolder =>
      '初期ライブラリを構築するために、音楽ファイル（MP3、FLAC、M4Aなど）が入ったメインフォルダを選択してください。';

  @override
  String get chooseTheme => 'テーマを選択';

  @override
  String get close => '閉じる';

  @override
  String get communityAndSupport => 'コミュニティ＆サポート';

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
  String get dangerZone => '危険ゾーン';

  @override
  String get dark => 'ダーク';

  @override
  String get darkSubtitle => '常にダークテーマを使用';

  @override
  String get dataManagement => 'データ管理';

  @override
  String get dateCreated => '作成日時';

  @override
  String get dateModified => '更新日時';

  @override
  String get defaultAppColor => '標準のアプリカラー';

  @override
  String get defaultSleepTimer => 'デフォルトスリープタイマー';

  @override
  String get defaultSleepTimerSubtitle => 'スリープタイマーを開いたときにデフォルトで選択される時間';

  @override
  String get defaultStartPage => 'デフォルト開始ページ';

  @override
  String get defaultStartPageSubtitle => 'アプリ起動時に表示されるページ';

  @override
  String get delete => '削除';

  @override
  String get deletePlaylist => 'プレイリストを削除';

  @override
  String deletePlaylistConfirmMessage(String name) {
    return '「$name」を削除しますか？この操作は取り消せません。';
  }

  @override
  String get deletePlaylistConfirmTitle => 'プレイリストを削除しますか？';

  @override
  String get developerProfile => '開発者プロフィール';

  @override
  String get developerProfileSubtitle => 'GitHubのyurtemre7を見る';

  @override
  String get displayedAs => '表示名:';

  @override
  String get download => 'ダウンロード';

  @override
  String get dynamicTheme => 'ダイナミックテーマ (Material You)';

  @override
  String get dynamicThemeSubtitle => '再生中のアルバムアートの色に合わせてアプリを自動着色します';

  @override
  String get enterDurationHint => '時間を入力';

  @override
  String get enterYourName => '名前を入力';

  @override
  String get failedToLoadChangelog => '更新履歴を読み込めませんでした。';

  @override
  String get favorites => 'お気に入り';

  @override
  String get fileSize => 'ファイルサイズ';

  @override
  String get filterTitleArtist => 'タイトルからアーティスト名を削除';

  @override
  String get filterTitleArtistSubtitle => '曲タイトルの先頭にある「アーティスト名 - 」を非表示にします。';

  @override
  String get filterTitleFeatures => 'タイトルから (feat.) を削除';

  @override
  String get filterTitleFeaturesSubtitle => '曲タイトルに含まれる客演情報を非表示にします。';

  @override
  String get formattingSettings => 'タイトルとメタデータの形式';

  @override
  String get formattingSubtitle => '曲タイトルの表示方法を設定します';

  @override
  String get getStarted => '始める';

  @override
  String goodAfternoon(String name) {
    return 'こんにちは、$nameさん';
  }

  @override
  String goodEvening(String name) {
    return 'こんばんは、$nameさん';
  }

  @override
  String goodMorning(String name) {
    return 'おはようございます、$nameさん';
  }

  @override
  String get infoSettings => '情報とサポート';

  @override
  String get infoSubtitle => 'アプリ情報、更新、変更履歴';

  @override
  String get keepPlayingOnClose => 'アプリ終了時も再生を継続';

  @override
  String get keepPlayingOnCloseSubtitle => 'アプリをスワイプして閉じてもバックグラウンドで再生を続けます';

  @override
  String get language => '言語';

  @override
  String get languageEnglish => '英語';

  @override
  String get languageGerman => 'ドイツ語';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageSystem => 'システム標準';

  @override
  String get lastSync => '最終同期';

  @override
  String get later => 'あとで';

  @override
  String get libraryFormatting => 'ライブラリの形式設定';

  @override
  String get librarySync => 'ライブラリ同期';

  @override
  String get licenses => 'ライセンス';

  @override
  String get licensesSubtitle => 'オープンソースライセンス';

  @override
  String get light => 'ライト';

  @override
  String get lightSubtitle => '常にライトテーマを使用';

  @override
  String get listeningStatistics => '再生統計';

  @override
  String get lyrics => '歌詞';

  @override
  String get mfx => 'MFX';

  @override
  String get mfxBassBoosted => 'ベースブースト';

  @override
  String get mfxLoFi => 'Lo-Fi / ヴィンテージルーム';

  @override
  String get mfxResetAll => 'すべてのエフェクトをリセット';

  @override
  String get mfxWarmth => '暖かみ（リバーブ）';

  @override
  String minuteAbbr(int min) {
    return '$min分';
  }

  @override
  String get minutes => '分';

  @override
  String get neverSynced => '未同期';

  @override
  String get next => '次へ';

  @override
  String get noAlbumsFound => 'アルバムが見つかりません';

  @override
  String get noArtistsFound => 'アーティストが見つかりません';

  @override
  String get noFavoritesYet => 'お気に入りがまだありません';

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
  String get noSongsFound => '曲が見つかりません';

  @override
  String get ok => 'OK';

  @override
  String get onboardingDescription =>
      '美しいMaterial 3 Expressiveデザインで作られたプレミアムなオフライン音楽体験。\n\nなめらかな再生とスピーディなバックグラウンドスキャンをお楽しみください。';

  @override
  String get openGithubReleases => 'GitHub Releasesを開く';

  @override
  String get originalMetadata => '元のメタデータ:';

  @override
  String get pauseOnDuck => '通知受信時に一時停止';

  @override
  String get pauseOnDuckSubtitle => '通知が届いた際に音量を下げるのではなく再生を一時停止します';

  @override
  String get permissionsExplained => '権限の説明';

  @override
  String get permissionsExplanation =>
      '音楽を再生・操作するために、Sonoraはデバイスのランタイム権限が必要です。';

  @override
  String get permissionsNeeded => '権限が必要です';

  @override
  String get personalization => 'パーソナライズ';

  @override
  String get play => '再生';

  @override
  String get playAll => 'すべて再生';

  @override
  String get playback => '再生';

  @override
  String get playbackSettings => '再生とオーディオ';

  @override
  String get playbackSubtitle => 'スリープタイマー、起動ページ、バックグラウンド再生';

  @override
  String playlistCount(int count) {
    return '$count プレイリスト';
  }

  @override
  String get playlistName => 'プレイリスト名';

  @override
  String get playlists => 'プレイリスト';

  @override
  String get preferLocalArtistImages => 'ローカルのアーティスト画像を優先';

  @override
  String get preferLocalArtistImagesSubtitle =>
      '音楽フォルダ内の local artist.jpg ファイルを優先的に使用します';

  @override
  String get preview => 'プレビュー';

  @override
  String get privacyCardDataContent =>
      'このアプリは完全にオフラインで動作し、GitHubのアップデート確認を除いてサーバーと通信しません。ライブラリ統計、設定、再生データはすべてデバイス上にのみ保存され、外部に送信されることはありません。\n\nあなたのリスニング習慣が確実にプライベートに保たれます。';

  @override
  String get privacyCardDataTitle => 'あなたのデータはあなたのもの';

  @override
  String get privacyCardDeleteDataContent =>
      'あなたは完全な制御権を持っています。「情報＆サポート」タブ下部の危険ゾーンから、すべてのアプリ設定・統計・キャッシュをいつでも即座に削除できます。';

  @override
  String get privacyCardDeleteDataTitle => '全データ削除';

  @override
  String get privacyCardInternetContent =>
      'GitHubから最新バージョンと更新履歴を取得し、利用可能なアップデートを通知するためだけに使用されます。';

  @override
  String get privacyCardInternetTitle => 'インターネット';

  @override
  String get privacyCardNotificationsContent =>
      '通知シェードとロック画面にメディアプレイヤーコントロールを表示するために使用されます。アプリを閉じた後もバックグラウンドで音楽を継続再生するためにフォアグラウンドサービスが必要です。';

  @override
  String get privacyCardNotificationsTitle => '通知・フォアグラウンドサービス';

  @override
  String get privacyCardStorageContent =>
      '選択した音楽フォルダ内の音楽ファイルおよびローカルアーティスト/アルバムアートワーク（例：artist.jpgやcover.png）のスキャンに使用されます。\n\nプライバシー保証：Androidが「写真とメディア」アクセスを求めますが、Sonoraは指定された音楽ディレクトリ内のファイルのみをスキャンします。個人の写真ギャラリーやプライベート画像には一切アクセスしません。';

  @override
  String get privacyCardStorageTitle => 'ストレージ・オーディオ・カバー画像';

  @override
  String get privacyCardWakeLockContent => 'デバイスがスリープ状態になって再生が突然停止しないようにします。';

  @override
  String get privacyCardWakeLockTitle => 'ウェイクロック';

  @override
  String get privacyPermissions => 'プライバシーと権限';

  @override
  String get privacySettings => 'プライバシーと権限';

  @override
  String get privacySubtitle => 'データ管理と必要な権限';

  @override
  String get queue => '再生キュー';

  @override
  String get queueEmpty => 'キューは空です';

  @override
  String get rateLimitMessage =>
      'GitHubのAPIレート制限（匿名リクエスト60回/時間）に達しました。\n\nGitHubリポジトリを直接開いて新しいリリースを確認してください。';

  @override
  String get rateLimitTitle => 'レート制限超過';

  @override
  String get removeCover => 'カバーを削除';

  @override
  String get rename => '名前を変更';

  @override
  String get renamePlaylist => 'プレイリスト名を変更';

  @override
  String get reset => 'リセット';

  @override
  String get resetAll => 'リセット';

  @override
  String get resetApplication => 'アプリをリセット';

  @override
  String get resetApplicationConfirmMessage =>
      'すべてのインポートされた音楽ファイルが完全に削除されライブラリがクリアされます。この操作は元に戻せません。';

  @override
  String get resetApplicationConfirmTitle => 'アプリをリセットしますか？';

  @override
  String get resetApplicationSubtitle => '3秒間長押しして全データを削除します。';

  @override
  String get resetStatistics => '統計をリセット';

  @override
  String get resetStatisticsConfirmMessage =>
      '総再生時間、再生回数、トップチャートを含むすべての統計データを永久に削除します。元に戻すことはできません。';

  @override
  String get resetStatisticsConfirmTitle => '統計をリセットしますか？';

  @override
  String get save => '保存';

  @override
  String get searchAlbumsHint => 'アルバムを検索...';

  @override
  String get searchArtistsHint => 'アーティストを検索...';

  @override
  String get searchPlaylistsHint => 'プレイリストを検索...';

  @override
  String get searchSongsHint => '曲、アーティストを検索...';

  @override
  String get selectFolder => 'フォルダを選択';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get selectedDirectory => '選択したディレクトリ：';

  @override
  String get setMusicDirectory => '音楽ディレクトリを設定';

  @override
  String get setSyncFolder => '同期フォルダを設定';

  @override
  String get settings => '設定';

  @override
  String get setupMusicDirectory => '音楽ディレクトリの設定';

  @override
  String get showAudioVisualizer => 'オーディオビジュアライザーを表示';

  @override
  String get showAudioVisualizerSubtitle => 'プレイヤー画面内にオーディオ波形アニメーションを表示します';

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
  String songCount(int count) {
    return '$count 曲';
  }

  @override
  String get songs => '曲';

  @override
  String get sort => '並べ替え';

  @override
  String get sortAlbumsBy => 'アルバムの並べ替え基準';

  @override
  String get sortArtistsBy => 'アーティストの並べ替え基準';

  @override
  String get sortAscending => '昇順で並べ替え';

  @override
  String get sortByAlbumCount => 'アルバム数';

  @override
  String get sortByAlbumName => 'アルバム名';

  @override
  String get sortByArtist => 'アーティスト';

  @override
  String get sortByArtistName => 'アーティスト名';

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
  String get sortPlaylistsBy => 'プレイリストの並べ替え基準';

  @override
  String get sortSongsBy => '曲の並べ替え基準';

  @override
  String get sortSubtitle => '並べ替えの設定はタブごとに保存され、次回起動時に自動適用されます。';

  @override
  String get sourceCode => 'ソースコード';

  @override
  String get sourceCodeSubtitle => 'GitHubリポジトリを表示';

  @override
  String get startTimer => 'タイマーを開始';

  @override
  String get stats => '統計';

  @override
  String get syncExplanation =>
      'Sonoraはファイルをローカル・オフラインで再生します。このフォルダに新しいトラックをコピーした場合は、以下から同期を実行してください。';

  @override
  String get syncNow => '今すぐ同期';

  @override
  String get syncing => '同期中...';

  @override
  String get systemDefault => 'システム標準';

  @override
  String get systemSubtitle => '端末のテーマ設定に従います';

  @override
  String get telegramContact => 'Telegramで連絡';

  @override
  String get telegramContactSubtitle => '@emredevへお問い合わせ';

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
    return '$count トラック';
  }

  @override
  String get tryAgain => 'もう一度試す';

  @override
  String get updateAvailable => 'アップデートあり';

  @override
  String updateAvailableMessage(String version) {
    return 'バージョン $version が利用可能です！';
  }

  @override
  String get updateCheckFailed => 'アップデートの確認に失敗しました。インターネット接続を確認してください。';

  @override
  String get useGreetingTitle => 'あいさつタイトルを使用';

  @override
  String get useGreetingTitleSubtitle => 'ホーム画面のアプリ名の代わりに時間帯に応じたあいさつを表示します';

  @override
  String get viewStatistics => '統計を表示';

  @override
  String get viewStatisticsSubtitle => '再生履歴と統計を確認します';

  @override
  String get volume => '音量';

  @override
  String get welcomeToSonora => 'Sonoraへようこそ';

  @override
  String get yourName => 'あなたの名前';

  @override
  String get yourNameOptional => 'あなたの名前（任意）';
}
