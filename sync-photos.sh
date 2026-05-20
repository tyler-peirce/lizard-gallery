#!/bin/bash
# sync-photos.sh
# Ensures git tracks photos for exactly the animals listed in animals.json.
# Run this after updating animals.json (adding or removing animals).
#
# What it does:
#   - Removes from git any photo folder whose ID is not in animals.json
#   - Adds to git any photo folder whose ID is in animals.json (if local folder exists)
#   - Photos on disk are never deleted — only git tracking changes

set -e
cd "$(dirname "$0")"

python3 - <<'PYEOF'
import json, subprocess, os

data = json.load(open('animals.json'))
json_ids = set(a['id'] for a in data['animals'])

# Current git-tracked photo folders
result = subprocess.run(['git', 'ls-files', 'photos/'], capture_output=True, text=True)
git_folders = set()
for line in result.stdout.strip().split('\n'):
    if line:
        parts = line.split('/')
        if len(parts) >= 2:
            git_folders.add(parts[1])

# Remove unlisted folders from git
to_remove = git_folders - json_ids
for folder_id in sorted(to_remove):
    print(f"  Removing from git: photos/{folder_id}/")
    subprocess.run(['git', 'rm', '-r', '--cached', f'photos/{folder_id}/'], check=True, capture_output=True)

# Add listed folders that exist locally but aren't tracked
to_add = json_ids - git_folders
added = []
missing = []
for folder_id in sorted(to_add):
    folder = f'photos/{folder_id}'
    if os.path.isdir(folder):
        subprocess.run(['git', 'add', '-f', folder], check=True)
        added.append(folder_id)
    else:
        missing.append(folder_id)

if to_remove:
    print(f"\nRemoved {len(to_remove)} unlisted folder(s) from git tracking.")
if added:
    print(f"Added {len(added)} newly listed folder(s) to git.")
if missing:
    print(f"No local photos found for: {', '.join(missing)}")
if not to_remove and not added:
    print("Photos already in sync with animals.json.")
PYEOF
