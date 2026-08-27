#!/usr/bin/env bash
set -Eeuo pipefail

die() {
  printf 'devin-ci: %s\n' "$*" >&2
  exit 2
}

# GitLab file-type variables contain a path to a temporary file. Copy the
# credentials into Devin's documented data directory without exposing them in
# the image or the job log.
credentials_dir="${XDG_DATA_HOME:-${HOME}/.local/share}/devin"
credentials_path="$credentials_dir/credentials.toml"

if [[ -n "${DEVIN_CREDENTIALS_FILE:-}" ]]; then
  install -d -m 700 "$credentials_dir"
  install -m 600 "$DEVIN_CREDENTIALS_FILE" "$credentials_path"
fi

if [[ ! -s "$credentials_path" ]]; then
  die "not authenticated; provide DEVIN_CREDENTIALS_FILE as a protected GitLab file variable"
fi

prompt=""
if [[ -n "${DEVIN_PROMPT_FILE:-}" ]]; then
  [[ -r "$DEVIN_PROMPT_FILE" ]] || die "cannot read DEVIN_PROMPT_FILE: $DEVIN_PROMPT_FILE"
  prompt="$(<"$DEVIN_PROMPT_FILE")"
elif [[ -n "${DEVIN_PROMPT:-}" ]]; then
  prompt="$DEVIN_PROMPT"
elif [[ ! -t 0 ]]; then
  prompt="$(cat)"
fi

[[ -n "$prompt" ]] || die "provide input through DEVIN_PROMPT, DEVIN_PROMPT_FILE, or stdin"

# SWE-1.6 is the default included model. DEVIN_MODEL allows an intentional
# migration later; the enterprise model allowlist remains the enforcement layer.
readonly selected_model="${DEVIN_MODEL:-swe-1.6}"
args=(--model "$selected_model" --print --respect-workspace-trust false)

if [[ -n "${DEVIN_PERMISSION_MODE:-}" ]]; then
  case "$DEVIN_PERMISSION_MODE" in
    normal|auto|accept-edits|smart|dangerous|yolo|bypass)
      args+=(--permission-mode "$DEVIN_PERMISSION_MODE")
      ;;
    *)
      die "invalid DEVIN_PERMISSION_MODE: $DEVIN_PERMISSION_MODE"
      ;;
  esac
fi

if [[ -n "${DEVIN_EXPORT_FILE:-}" ]]; then
  mkdir -p "$(dirname "$DEVIN_EXPORT_FILE")"
  args+=(--export "$DEVIN_EXPORT_FILE")
fi

if [[ -n "${DEVIN_OUTPUT_FILE:-}" ]]; then
  mkdir -p "$(dirname "$DEVIN_OUTPUT_FILE")"
  devin "${args[@]}" -- "$prompt" | tee "$DEVIN_OUTPUT_FILE"
else
  exec devin "${args[@]}" -- "$prompt"
fi
