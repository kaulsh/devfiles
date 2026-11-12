#!/usr/bin/env bash
# Link each skill in this folder into Claude Code's skills dir.
#
# ~/.claude/skills can't be a symlink to this folder (like ~/.cursor/skills is)
# because Claude Code keeps its own `synced/` and `.trash/` dirs in there. So we
# link skills one by one instead. Safe to re-run: existing links are refreshed,
# real dirs are never touched, and links to skills deleted from here are pruned.
#
# Usage: ./link-claude-skills.sh [-n]   (-n = dry run)
set -euo pipefail

DRY=""
[ "${1:-}" = "-n" ] && DRY="echo [dry-run]"

SRC="$(cd "$(dirname "$0")" && pwd -P)"
DST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$DST"

# Link every subfolder that contains a SKILL.md.
for dir in "$SRC"/*/; do
  dir="${dir%/}"
  name="$(basename "$dir")"
  [ -f "$dir/SKILL.md" ] || continue
  target="$DST/$name"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "skip   $name (a real file/dir already exists at $target)"
    continue
  fi
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$dir" ]; then
    continue
  fi
  $DRY ln -sfn "$dir" "$target"
  echo "link   $name"
done

# Prune links that point into this folder but whose skill no longer exists.
for link in "$DST"/*; do
  [ -L "$link" ] || continue
  case "$(readlink "$link")" in
    "$SRC"/*)
      if [ ! -f "$link/SKILL.md" ]; then
        $DRY rm "$link"
        echo "prune  $(basename "$link")"
      fi
      ;;
  esac
done
