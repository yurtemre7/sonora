import subprocess
import re

def run_command(cmd):
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, shell=True)
    if result.returncode != 0:
        return ""
    return result.stdout.strip()

def get_tags():
    tags_raw = run_command("git tag --sort=-v:refname")
    if not tags_raw:
        return []
    return [t for t in tags_raw.split('\n') if t.strip()]

def get_tag_date(tag):
    return run_command(f"git log -1 --format=%as {tag}")

def get_commits_between(prev_tag, current_tag):
    range_str = f"{prev_tag}..{current_tag}" if prev_tag else current_tag
    commits_raw = run_command(f'git log {range_str} --no-merges --pretty=format:"%s"')
    if not commits_raw:
        return []
    return [c for c in commits_raw.split('\n') if c.strip()]

def parse_commit(commit_msg):
    match = re.match(r'^(\w+)(?:\(([^)]+)\))?:\s*(.*)$', commit_msg)
    if match:
        commit_type = match.group(1).lower()
        message = match.group(3)
        return commit_type, message
    return None, commit_msg

def generate_changelog():
    tags = get_tags()
    
    changelog_content = [
        "# Changelog\n",
        "All notable changes to the Sonora music player project are documented in this file.\n"
    ]
    
    for i, tag in enumerate(tags):
        tag_date = get_tag_date(tag)
        version_clean = tag.lstrip('v').split('+')[0]
        
        prev_tag = tags[i+1] if i + 1 < len(tags) else None
        commits = get_commits_between(prev_tag, tag)
        
        added = []
        fixed = []
        changed = []
        
        for commit in commits:
            if any(x in commit.lower() for x in ["release: v", "bump version", "merge branch"]):
                continue
                
            commit_type, msg = parse_commit(commit)
            if msg:
                msg = msg[0].upper() + msg[1:]
                
            if commit_type == 'feat':
                added.append(msg)
            elif commit_type == 'fix':
                fixed.append(msg)
            elif commit_type in ['refactor', 'style', 'perf', 'docs', 'chore']:
                changed.append(f"{commit_type.capitalize()}: {msg}")
            else:
                msg_lower = msg.lower()
                if msg_lower.startswith('add') or 'implement' in msg_lower:
                    added.append(msg)
                elif msg_lower.startswith('fix') or 'prevent' in msg_lower:
                    fixed.append(msg)
                else:
                    changed.append(msg)
                    
        changelog_content.append(f"## [{version_clean}] - {tag_date}")
        
        if added:
            changelog_content.append("### Added")
            for item in added:
                changelog_content.append(f"* {item}")
        if fixed:
            changelog_content.append("### Fixed")
            for item in fixed:
                changelog_content.append(f"* {item}")
        if changed:
            changelog_content.append("### Changed")
            for item in changed:
                changelog_content.append(f"* {item}")
                
        changelog_content.append("")
        
    with open('CHANGELOG.md', 'w') as f:
        f.write('\n'.join(changelog_content))
        
    print("CHANGELOG.md generated successfully!")

if __name__ == "__main__":
    generate_changelog()
