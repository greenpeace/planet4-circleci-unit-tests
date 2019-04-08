#!/usr/bin/env bats
set -eu

load .env

@test "$(basename "${BATS_SOURCE//.bats/}") --version" {
  expected="PHP ${TESTVERSION}"
  run run_docker_binary "$BATS_IMAGE" "$(basename "${BATS_SOURCE//.bats/}")" --version
  [ $status -eq 0 ]
  printf '%s' "$output" | grep -Eq "$expected"
}
