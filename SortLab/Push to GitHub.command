#!/bin/bash
# Publishes this folder to GitHub: copies it into a clone of the repo, commits and pushes.
# Double-click it, or run:  bash "Push to GitHub.command"   (add --dry-run to preview without pushing)

REPO_URL="https://github.com/Iankim22233/Visual-Sorter-Macos.git"
SUBDIR="SortLab"                       # folder inside the repo that this project lives in
WORK="$HOME/.sortlab-publish"          # private clone used for publishing
DRY=0; [ "$1" = "--dry-run" ] && DRY=1

say()  { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
done_() { [ -t 0 ] && { read -n 1 -s -r -p "Press any key to close."; echo; }; }
fail() { printf '\n\033[31mFailed: %s\033[0m\n' "$1"; done_; exit 1; }

command -v git >/dev/null 2>&1 || fail "git isn't installed (run: xcode-select --install)."
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/Package.swift" ] || fail "Run this from the SortLab project folder (Package.swift not found)."

# 1. Get an up-to-date clone.
if [ -d "$WORK/.git" ]; then
  say "Updating local clone…"
  git -C "$WORK" fetch origin >/dev/null 2>&1 && git -C "$WORK" pull --rebase --autostash -q \
    || fail "Couldn't update $WORK. Delete it (rm -rf \"$WORK\") and run again."
else
  say "Cloning $REPO_URL …"
  rm -rf "$WORK"
  git clone -q "$REPO_URL" "$WORK" || fail "Clone failed. Check the URL and your GitHub login."
fi

# 2. Copy the project in (removes files you deleted; skips build output and this script).
say "Copying files…"
mkdir -p "$WORK/$SUBDIR"
rsync -a --delete \
  --exclude '.build/' --exclude 'SortLab.app' --exclude '.DS_Store' --exclude '.git/' \
  --exclude 'Push to GitHub.command' \
  "$HERE/" "$WORK/$SUBDIR/" || fail "rsync failed."

cd "$WORK" || fail "Can't enter $WORK"
git add -A
# Keep the scripts executable for everyone who clones.
for f in "$SUBDIR/build.sh" "$SUBDIR/Install SortLab.command"; do
  [ -f "$f" ] && git update-index --add --chmod=+x -- "$f"
done

if git diff --cached --quiet; then
  say "Nothing to publish: GitHub already matches this folder."
  done_; exit 0
fi

say "Changes to publish:"
git status --short
[ "$DRY" = 1 ] && { say "Dry run: nothing committed or pushed."; done_; exit 0; }

# 3. Commit and push.
git config user.name >/dev/null || fail "Set your git identity first:
  git config --global user.name \"Your Name\"
  git config --global user.email \"you@example.com\""
printf '\nCommit message (Return for "Update SortLab"): '
read -r MSG
[ -z "$MSG" ] && MSG="Update SortLab"
git commit -q -m "$MSG" || fail "Commit failed."

say "Pushing…"
if git push -q origin HEAD; then
  say "Published: ${REPO_URL%.git}"
else
  fail "Push failed. If it asked for a login, sign in with GitHub (e.g. 'gh auth login'), or use a personal access token as the password, then run this again."
fi
done_
