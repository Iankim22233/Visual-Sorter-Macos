#!/bin/bash
# One-click installer: double-click this file in Finder.
# Gets the source (if it isn't already next to this script), builds SortLab, installs it and opens it.

REPO_URL="https://github.com/Iankim22233/Visual-Sorter-Macos.git"
CLONE_DIR="$HOME/.sortlab-source"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$1"; }
fail() { printf '\n\033[31mFailed: %s\033[0m\n' "$1"; read -n 1 -s -r -p "Press any key to close."; echo; exit 1; }

# 1. Need the Swift toolchain to build.
if ! command -v swift >/dev/null 2>&1; then
  say "Swift isn't installed. Starting the Command Line Tools installer…"
  xcode-select --install 2>/dev/null
  fail "Finish the Command Line Tools install, then double-click this installer again."
fi

# 2. Find the source: next to this script, or clone it.
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$HERE/Package.swift" ]; then
  SRC="$HERE"
else
  command -v git >/dev/null 2>&1 || fail "git isn't installed (run: xcode-select --install)."
  if [ -d "$CLONE_DIR/.git" ]; then
    say "Updating source…"
    git -C "$CLONE_DIR" pull --ff-only || fail "Could not update $CLONE_DIR"
  else
    say "Downloading source…"
    rm -rf "$CLONE_DIR"
    git clone --depth 1 "$REPO_URL" "$CLONE_DIR" || fail "Could not clone $REPO_URL"
  fi
  SRC="$(dirname "$(find "$CLONE_DIR" -name Package.swift -not -path '*/.build/*' | head -n 1)")"
  [ -f "$SRC/Package.swift" ] || fail "Package.swift not found in the downloaded source."
fi

# 3. Build. (Run through bash so it works even if build.sh lost its execute permission.)
say "Building SortLab (the first build can take a minute)…"
( cd "$SRC" && bash build.sh ) || fail "The build failed. The messages above say why."
[ -d "$SRC/SortLab.app" ] || fail "Build finished but SortLab.app wasn't created."

# 4. Install into /Applications (falls back to ~/Applications).
DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
say "Installing to $DEST…"
pkill -x SortLab 2>/dev/null
rm -rf "$DEST/SortLab.app"
cp -R "$SRC/SortLab.app" "$DEST/SortLab.app" || fail "Could not copy the app to $DEST"
chmod +x "$DEST/SortLab.app/Contents/MacOS/SortLab"
xattr -dr com.apple.quarantine "$DEST/SortLab.app" 2>/dev/null

say "Done. Opening SortLab…"
open "$DEST/SortLab.app"
sleep 1
