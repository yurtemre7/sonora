import json

def update_arb(file_path, updates):
    with open(file_path, 'r') as f:
        data = json.load(f)
    
    for k, v in updates.items():
        data[k] = v
        
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

en_updates = {
    "appDescription": "A beautiful local music player for Android, built with Flutter and Material 3 Expressive design.",
    "madeWithLove": "Made with ❤️ by yurtemre"
}

de_updates = {
    "appDescription": "Ein wunderschöner lokaler Musikplayer für Android, entwickelt mit Flutter und Material 3 Expressive Design.",
    "madeWithLove": "Gemacht mit ❤️ von yurtemre"
}

ja_updates = {
    "appDescription": "FlutterとMaterial 3 Expressiveデザインで構築された、Android向けの美しいローカル音楽プレーヤーです。",
    "madeWithLove": "yurtemreによって❤️を込めて作られました"
}

update_arb('lib/l10n/app_en.arb', en_updates)
update_arb('lib/l10n/app_de.arb', de_updates)
update_arb('lib/l10n/app_ja.arb', ja_updates)
