#!/usr/bin/env bash
set -euo pipefail

LOCAL_MODEL="${CLAUDE_LOCAL_MODEL:-glm-4.7-flash:latest}"

usage() {
  cat <<'USAGE'
Usage:
  ai-router.sh --local
  ai-router.sh --cloud
  ai-router.sh --auto "task description"
  ai-router.sh --auto "task description" --print-only

Modes:
  --local       Force local backend
  --cloud       Force cloud backend
  --auto        Choose backend using heuristics from the task description

Options:
  --print-only  Show the chosen mode and command without launching Claude
USAGE
}

mode=""
task=""
print_only=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      mode="local"
      shift
      ;;
    --cloud)
      mode="cloud"
      shift
      ;;
    --auto)
      mode="auto"
      shift
      if [[ $# -eq 0 ]]; then
        echo "ERROR: --auto requires a task description" >&2
        exit 1
      fi
      task="$1"
      shift
      ;;
    --print-only)
      print_only=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$mode" ]]; then
  echo "ERROR: choose one of --local, --cloud, or --auto" >&2
  usage
  exit 1
fi

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

contains_any() {
  local haystack="$1"
  shift
  local needle
  for needle in "$@"; do
    if [[ "$haystack" == *"$needle"* ]]; then
      return 0
    fi
  done
  return 1
}

choose_mode_auto() {
  local lowered
  lowered="$(to_lower "$task")"

  local cloud_keywords=(
    "rename"
    "move"
    "delete"
    "refactor"
    "apply"
    "across repo"
    "across repos"
    "multi-file"
    "rewrite"
    "migration"
    "bulk"
    "modify files"
    "edit many files"
    "architecture"
    "high-stakes"
  )

  local local_keywords=(
    "analyze"
    "summarize"
    "classify"
    "draft script"
    "draft a script"
    "propose"
    "plan"
    "brainstorm"
    "explain"
    "inspect"
    "compare"
    "outline"
    "find candidates"
    "review"
  )

  # Safer bias: if cloud-style terms appear, choose cloud
  if contains_any "$lowered" "${cloud_keywords[@]}"; then
    printf 'cloud\n'
    return 0
  fi

  if contains_any "$lowered" "${local_keywords[@]}"; then
    printf 'local\n'
    return 0
  fi

  # Default when unclear: cloud for reliability
  printf 'cloud\n'
}

launch_local() {
  if [[ "$print_only" -eq 1 ]]; then
    echo "Mode: local"
    echo "Command:"
    echo "  ANTHROPIC_AUTH_TOKEN=ollama ANTHROPIC_API_KEY=\"\" ANTHROPIC_BASE_URL=http://localhost:11434 claude --model ${LOCAL_MODEL}"
    return 0
  fi

  echo "Mode: local"
  echo "Model: ${LOCAL_MODEL}"
  if [[ -n "$task" ]]; then
    echo "Task (paste into Claude after launch):"
    echo "  $task"
  fi

  ANTHROPIC_AUTH_TOKEN=ollama \
  ANTHROPIC_API_KEY="" \
  ANTHROPIC_BASE_URL=http://localhost:11434 \
  exec claude --model "${LOCAL_MODEL}"
}

launch_cloud() {
  if [[ "$print_only" -eq 1 ]]; then
    echo "Mode: cloud"
    echo "Command:"
    echo "  claude"
    return 0
  fi

  echo "Mode: cloud"
  if [[ -n "$task" ]]; then
    echo "Task (paste into Claude after launch):"
    echo "  $task"
  fi

  exec claude
}

if [[ "$mode" == "auto" ]]; then
  mode="$(choose_mode_auto)"
fi

case "$mode" in
  local)
    launch_local
    ;;
  cloud)
    launch_cloud
    ;;
  *)
    echo "ERROR: invalid mode resolution" >&2
    exit 1
    ;;
esac
