#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALL_JS="$ROOT_DIR/install.js"

if [[ ! -f "$INSTALL_JS" ]]; then
  echo "FAIL: install.js not found at $INSTALL_JS" >&2
  exit 1
fi

declare -a TMP_DIRS=()

cleanup() {
  for dir in "${TMP_DIRS[@]}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

make_project() {
  local dir
  dir="$(mktemp -d /tmp/fltk-install-regression-XXXXXX)"
  TMP_DIRS+=("$dir")
  mkdir -p "$dir/project"
  printf '%s' "$dir/project"
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

test_copy_to_link_blocks_noninteractive_modified_file() {
  local project target output status
  project="$(make_project)"

  (cd "$project" && node "$INSTALL_JS" --copy >/dev/null)

  target="$project/.claude/agents/ms-flutter-reviewer.md"
  printf '\nLOCAL EDIT\n' >>"$target"

  set +e
  output="$(cd "$project" && node "$INSTALL_JS" 2>&1)"
  status=$?
  set -e

  [[ $status -ne 0 ]] || fail "copy->link with modified file should fail non-interactively"
  grep -q "Local modifications detected" <<<"$output" || fail "expected conflict error message for modified file"
  [[ ! -L "$target" ]] || fail "modified file should not be replaced with symlink"
  grep -q "LOCAL EDIT" "$target" || fail "modified file content should be preserved"

  echo "PASS: copy->link blocks non-interactive overwrite of modified file"
}

test_copy_to_link_force_overwrites_modified_file() {
  local project target output
  project="$(make_project)"

  (cd "$project" && node "$INSTALL_JS" --copy >/dev/null)

  target="$project/.claude/agents/ms-flutter-reviewer.md"
  printf '\nLOCAL EDIT\n' >>"$target"

  output="$(cd "$project" && node "$INSTALL_JS" --force 2>&1)"

  [[ -L "$target" ]] || fail "--force should replace modified file with symlink"
  grep -q "overwriting" <<<"$output" || fail "expected overwrite warning in --force output"
  if grep -q "LOCAL EDIT" "$target"; then
    fail "--force result should not keep local edit content"
  fi

  echo "PASS: copy->link --force overwrites and symlinks modified file"
}

test_copy_mode_converts_relative_skill_symlink() {
  local project symlink_dir source rel target
  project="$(make_project)"
  mkdir -p "$project/.claude/skills"

  symlink_dir="$(cd "$project/.claude/skills" && pwd -P)"
  source="$ROOT_DIR/skills/flutter-code-quality"
  rel="$(node -e "const path=require('path');console.log(path.relative(process.argv[1], process.argv[2]));" "$symlink_dir" "$source")"

  ln -s "$rel" "$project/.claude/skills/flutter-code-quality"

  (cd "$project" && node "$INSTALL_JS" --copy >/dev/null)

  target="$project/.claude/skills/flutter-code-quality"
  [[ ! -L "$target" ]] || fail "copy mode should replace relative toolkit symlink with real directory"
  [[ -d "$target" ]] || fail "expected real skill directory after copy mode"
  [[ -f "$target/SKILL.md" ]] || fail "expected copied skill contents after symlink conversion"

  echo "PASS: copy mode converts relative skill symlink into copied directory"
}

main() {
  test_copy_to_link_blocks_noninteractive_modified_file
  test_copy_to_link_force_overwrites_modified_file
  test_copy_mode_converts_relative_skill_symlink
  echo "All install regression tests passed."
}

main "$@"
