import subprocess
import re
import datetime
import os

def run_command(cmd):
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=True)
    if result.returncode != 0:
        return ""
    return result.stdout.strip()

def get_pubspec_version():
    try:
        with open('pubspec.yaml', 'r') as f:
            for line in f:
                if line.startswith('version:'):
                    val = line.split(':')[1].strip()
                    return val.split('+')[0]
    except Exception:
        pass
    return ""

def parse_changelog_existing():
    """Parses existing manual entries in CHANGELOG.md to ensure manually written bullet points are preserved."""
    if not os.path.exists('CHANGELOG.md'):
        return {}
    
    version_sections = {}
    current_version = None
    
    with open('CHANGELOG.md', 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    for line in lines:
        line_str = line.strip()
        version_match = re.match(r'^##\s*\[([^\]]+)\](?:\s*-\s*(.*))?', line_str)
        if version_match:
            current_version = version_match.group(1).strip()
            date_str = version_match.group(2).strip() if version_match.group(2) else ""
            if current_version not in version_sections:
                version_sections[current_version] = {'date': date_str, 'content': []}
        elif current_version and line_str.startswith('*'):
            version_sections[current_version]['content'].append(line_str)
            
    return version_sections

def generate_changelog():
    pub_version = get_pubspec_version()
    existing_sections = parse_changelog_existing()
    today = datetime.date.today().isoformat()
    
    # Get git commits log with commit hash, date, and subject
    git_log_raw = run_command('git log --pretty=format:"%h|%as|%s"')
    commits = []
    if git_log_raw:
        for line in git_log_raw.split('\n'):
            parts = line.split('|', 2)
            if len(parts) == 3:
                commits.append({'hash': parts[0], 'date': parts[1], 'subject': parts[2]})
                
    # Group commits by version boundaries
    version_buckets = {}
    current_ver = pub_version if pub_version else "Unreleased"
    
    if current_ver not in version_buckets:
        version_buckets[current_ver] = {'date': today, 'added': [], 'fixed': [], 'changed': []}
        
    for c in commits:
        subj = c['subject']
        date = c['date']
        
        # Check if this commit marks a release version bump
        rel_match = re.match(r'^release:\s*v?(\d+\.\d+\.\d+)', subj, re.IGNORECASE)
        if rel_match:
            ver = rel_match.group(1)
            # Check if there's descriptive text after release
            desc = re.sub(r'^release:\s*v?\d+\.\d+\.\d+(?:\+\d+)?(?:\s*-\s*|\s*:\s*|\s+)?', '', subj, flags=re.IGNORECASE).strip()
            if desc and not re.match(r'^\d+$', desc):
                desc_cap = desc[0].upper() + desc[1:]
                version_buckets[current_ver]['changed'].append(desc_cap)
            
            # Switch to the version defined by the release commit for subsequent earlier commits
            current_ver = ver
            if current_ver not in version_buckets:
                version_buckets[current_ver] = {'date': date, 'added': [], 'fixed': [], 'changed': []}
            continue

        if current_ver not in version_buckets:
            version_buckets[current_ver] = {'date': date, 'added': [], 'fixed': [], 'changed': []}
            
        # Parse conventional commit type
        msg_match = re.match(r'^(\w+)(?:\(([^)]+)\))?:\s*(.*)$', subj)
        if msg_match:
            ctype = msg_match.group(1).lower()
            msg = msg_match.group(3).strip()
            if not msg:
                continue
            msg_cap = msg[0].upper() + msg[1:]
            
            if ctype == 'feat':
                version_buckets[current_ver]['added'].append(msg_cap)
            elif ctype == 'fix':
                version_buckets[current_ver]['fixed'].append(msg_cap)
            elif ctype in ['refactor', 'style', 'perf', 'docs', 'chore']:
                version_buckets[current_ver]['changed'].append(f"{ctype.capitalize()}: {msg_cap}")
            else:
                version_buckets[current_ver]['changed'].append(msg_cap)
        else:
            msg_lower = subj.lower()
            subj_cap = subj[0].upper() + subj[1:]
            if msg_lower.startswith('add') or 'implement' in msg_lower:
                version_buckets[current_ver]['added'].append(subj_cap)
            elif msg_lower.startswith('fix') or 'prevent' in msg_lower:
                version_buckets[current_ver]['fixed'].append(subj_cap)
            elif not any(x in msg_lower for x in ["merge branch", "bump version"]):
                version_buckets[current_ver]['changed'].append(subj_cap)
                
    changelog_lines = [
        "# Changelog\n",
        "All notable changes to the Sonora music player project are documented in this file.\n"
    ]
    
    # Combine version buckets with existing sections to ensure nothing is lost
    all_versions = list(version_buckets.keys())
    for ex_ver in existing_sections:
        if ex_ver not in all_versions and ex_ver != "Unreleased":
            all_versions.append(ex_ver)
            
    for ver in all_versions:
        bdata = version_buckets.get(ver, {'date': today, 'added': [], 'fixed': [], 'changed': []})
        ex_data = existing_sections.get(ver, {'date': bdata['date'], 'content': []})
        date_str = bdata['date'] if bdata['date'] else (ex_data['date'] if ex_data['date'] else today)
        
        added = list(dict.fromkeys(bdata['added']))
        fixed = list(dict.fromkeys(bdata['fixed']))
        changed = list(dict.fromkeys(bdata['changed']))
        
        manual_bullets = ex_data['content']
        
        if added or fixed or changed or manual_bullets:
            changelog_lines.append(f"## [{ver}] - {date_str}")
            
            if added:
                changelog_lines.append("### Added")
                for item in added:
                    changelog_lines.append(f"* {item}")
            if fixed:
                changelog_lines.append("### Fixed")
                for item in fixed:
                    changelog_lines.append(f"* {item}")
            if changed:
                changelog_lines.append("### Changed")
                for item in changed:
                    changelog_lines.append(f"* {item}")
                    
            if manual_bullets and not (added or fixed or changed):
                for bullet in manual_bullets:
                    changelog_lines.append(bullet)
                    
            changelog_lines.append("")
            
    with open('CHANGELOG.md', 'w', encoding='utf-8') as f:
        f.write('\n'.join(changelog_lines))
        
    print("CHANGELOG.md generated successfully!")

if __name__ == "__main__":
    generate_changelog()
