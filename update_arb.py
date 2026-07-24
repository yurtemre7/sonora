import json

def update_arb(file_path, updates):
    with open(file_path, 'r') as f:
        data = json.load(f)
    
    for k, v in updates.items():
        data[k] = v
        
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

en_updates = {
    "activeSyncLocation": "Active sync location",
    "syncLibraryDatabase": "Sync Library Database?",
    "syncLibraryDatabaseSubtitle": "It's been at least a month since your last library synchronization. Sonora runs offline—if you have loaded new music files into your device folder, run a sync now to discover and listen to them.",
    "appInfo": "App Info",
    "version": "Version {version}",
    "@version": {
        "placeholders": {
            "version": { "type": "String" }
        }
    },
    "resetStatisticsTitle": "Reset Statistics?",
    "resetStatisticsWarning": "This will permanently delete all your listening statistics, including total time, play counts, and top charts. This cannot be undone.",
    "queueIsEmpty": "Queue is empty",
    "queueXOfY": "Queue ({current} of {total})",
    "@queueXOfY": {
        "placeholders": {
            "current": { "type": "int" },
            "total": { "type": "int" }
        }
    },
    "queue": "Queue",
    "upNextCaps": "UP NEXT",
    "upNext": "Up next",
    "lyricsCaps": "LYRICS",
    "noLyricsAvailable": "No lyrics available",
    "relatedCaps": "RELATED",
    "related": "Related",
    "noRelatedSongs": "No related songs",
    "noLyricsFound": "No lyrics found",
    "placeLrcFile": "Place a .lrc or .txt file with the same name next to the audio file to load lyrics.",
    "songInformation": "Song Information",
    "presetSpeedAndPitch": "Preset Speed & Pitch",
    "customSpeed": "Custom Speed",
    "syncedXSongs": "Synced {count} songs{duration}.",
    "@syncedXSongs": {
        "placeholders": {
            "count": { "type": "int" },
            "duration": { "type": "String" }
        }
    },
    "syncDuration": " in {duration}ms",
    "@syncDuration": {
        "placeholders": {
            "duration": { "type": "String" }
        }
    },
    "plusOneMin": "+1 min",
    "delete": "Delete"
}

de_updates = {
    "activeSyncLocation": "Aktiver Sync-Speicherort",
    "syncLibraryDatabase": "Bibliotheksdatenbank synchronisieren?",
    "syncLibraryDatabaseSubtitle": "Es ist mindestens ein Monat seit deiner letzten Synchronisierung vergangen. Sonora läuft offline — wenn du neue Musikdateien in deinen Geräteordner geladen hast, führe jetzt eine Synchronisierung durch, um sie zu entdecken.",
    "appInfo": "App-Info",
    "version": "Version {version}",
    "resetStatisticsTitle": "Statistiken zurücksetzen?",
    "resetStatisticsWarning": "Dadurch werden all deine Hörstatistiken, einschließlich der Gesamtzeit, Wiedergabezahlen und Top-Charts, dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.",
    "queueIsEmpty": "Warteschlange ist leer",
    "queueXOfY": "Warteschlange ({current} von {total})",
    "queue": "Warteschlange",
    "upNextCaps": "ALS NÄCHSTES",
    "upNext": "Als nächstes",
    "lyricsCaps": "SONGTEXT",
    "noLyricsAvailable": "Kein Songtext verfügbar",
    "relatedCaps": "ÄHNLICH",
    "related": "Ähnlich",
    "noRelatedSongs": "Keine ähnlichen Songs",
    "noLyricsFound": "Kein Songtext gefunden",
    "placeLrcFile": "Platziere eine .lrc- oder .txt-Datei mit demselben Namen neben der Audiodatei, um den Songtext zu laden.",
    "songInformation": "Song-Informationen",
    "presetSpeedAndPitch": "Voreingestellte Geschwindigkeit & Tonhöhe",
    "customSpeed": "Benutzerdefinierte Geschwindigkeit",
    "syncedXSongs": "{count} Songs synchronisiert{duration}.",
    "syncDuration": " in {duration}ms",
    "plusOneMin": "+1 Min",
    "delete": "Löschen"
}

ja_updates = {
    "activeSyncLocation": "現在のアクティブな同期先",
    "syncLibraryDatabase": "ライブラリデータベースを同期しますか？",
    "syncLibraryDatabaseSubtitle": "最後のライブラリ同期から少なくとも1ヶ月が経過しました。Sonoraはオフラインで動作します。デバイスフォルダに新しい音楽ファイルを読み込んだ場合は、今すぐ同期を実行して見つけて聴いてください。",
    "appInfo": "アプリ情報",
    "version": "バージョン {version}",
    "resetStatisticsTitle": "統計をリセットしますか？",
    "resetStatisticsWarning": "これにより、合計時間、再生回数、トップチャートを含むすべてのリスニング統計が永久に削除されます。この操作は元に戻せません。",
    "queueIsEmpty": "キューは空です",
    "queueXOfY": "キュー ({current} / {total})",
    "queue": "キュー",
    "upNextCaps": "次に再生",
    "upNext": "次に再生",
    "lyricsCaps": "歌詞",
    "noLyricsAvailable": "歌詞はありません",
    "relatedCaps": "関連",
    "related": "関連",
    "noRelatedSongs": "関連曲はありません",
    "noLyricsFound": "歌詞が見つかりません",
    "placeLrcFile": "歌詞を読み込むには、同じ名前の.lrcまたは.txtファイルをオーディオファイルの横に配置します。",
    "songInformation": "曲の情報",
    "presetSpeedAndPitch": "プリセット速度とピッチ",
    "customSpeed": "カスタム速度",
    "syncedXSongs": "{count} 曲を同期しました{duration}。",
    "syncDuration": "（{duration}ms）",
    "plusOneMin": "+1分",
    "delete": "削除"
}

update_arb('lib/l10n/app_en.arb', en_updates)
update_arb('lib/l10n/app_de.arb', de_updates)
update_arb('lib/l10n/app_ja.arb', ja_updates)
