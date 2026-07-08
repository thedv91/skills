#!/usr/bin/env bash
# file-hooks dispatcher — run project-defined commands on the file Claude just changed.
#
# Reads the PostToolUse payload (Edit|Write) from stdin, looks up the current
# project's .claude/file-hooks.json, and runs every command whose `match`
# regex matches the changed file. Commands are keyed by a "phase" ($1) so the
# caller can split fast/blocking work (e.g. "format") from slow background
# work (e.g. "check") across separate hook entries in hooks.json.
#
# The mechanism (extract → match → run) lives here and is shared across
# projects via the plugin; the actual commands are policy and live per-project
# in .claude/file-hooks.json. A project with no config file is a no-op.
#
# Config MUST be a dedicated .claude/file-hooks.json — Claude Code rejects
# unknown top-level keys in settings.json/settings.local.json, so the rules
# cannot live there.
#
# Config shape (.claude/file-hooks.json):
#   { "<phase>": [ { "match": "<regex>", "commands": ["cmd {file}", ...] } ] }
# {file} is replaced with the shell-quoted path of the changed file.

# Intentionally NOT using `set -e`: a PostToolUse hook must never fail the tool
# call, so every command is guarded and the script always exits 0.

phase="${1:-format}"

# Tool payload arrives on stdin as JSON: { "tool_input": { "file_path": ... } }
file=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file" ] && exit 0

project="${CLAUDE_PROJECT_DIR:-$PWD}"
config="$project/.claude/file-hooks.json"
[ -f "$config" ] || exit 0

# Run tools from the project root so they discover their own config (eslint,
# tsconfig, etc.). Bail quietly if the dir vanished.
cd "$project" 2>/dev/null || exit 0

# `printf %q` shell-quotes the path so paths with spaces/specials survive the
# `eval` below. Config is authored per-project and trusted — not external input.
safe_file=$(printf '%q' "$file")

jq -c --arg phase "$phase" '.[$phase] // [] | .[]' "$config" 2>/dev/null | while IFS= read -r rule; do
  pattern=$(jq -r '.match // empty' <<<"$rule")
  [ -z "$pattern" ] && continue
  printf '%s' "$file" | grep -qE "$pattern" || continue
  jq -r '.commands[]?' <<<"$rule" | while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    eval "${cmd//'{file}'/$safe_file}" 2>&1 || true
  done
done

exit 0
