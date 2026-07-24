import json

def update_arb(file_path, updates):
    with open(file_path, 'r') as f:
        data = json.load(f)
    
    for k, v in updates.items():
        data[k] = v
        
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

en_updates = { 
    "stopInX": "Stop in {duration}",
    "@stopInX": {
        "placeholders": {
            "duration": { "type": "String" }
        }
    }
}
de_updates = { "stopInX": "Stoppt in {duration}" }
ja_updates = { "stopInX": "{duration}後に停止" }

update_arb('lib/l10n/app_en.arb', en_updates)
update_arb('lib/l10n/app_de.arb', de_updates)
update_arb('lib/l10n/app_ja.arb', ja_updates)
