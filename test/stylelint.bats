#!/usr/bin/env bats
set -eu

load .env

filename="$(basename "$BATS_TEST_FILENAME" | cut -d. -f1)"

@test "($filename --version)" {
  expected="$VERSION_REGEX"
  run run_docker_binary "$BATS_IMAGE" "$filename --version"
  [ $status -eq 0 ]
  printf '%s' "$output" | grep -Eq "$expected"
}
