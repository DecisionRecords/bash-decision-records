#!/usr/bin/env ./libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "../decision-records.sh"
  DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." >/dev/null 2>&1 && pwd -P)"
  PATH="$DIR:$PATH"
  cd "$BATS_TEST_TMPDIR"
  BATS_TEST_TMPDIR="$(pwd -P)"
}

teardown() {
  cd /
  rm -Rf "$BATS_TEST_TMPDIR"
}

@test "01-01 No valid directories found" {
  run _get_decision_record_root
  assert_output --partial '[ Error ]: No decision records root found. Have you run `'
  assert_output --partial ' init`?'
  assert_failure
}

@test "01-02 Find basic doc/adr directory" {
  mkdir -p doc/adr
  run _get_decision_record_root
  assert_output "$BATS_TEST_TMPDIR"
  assert_success
}

@test "01-02a Find basic doc/adr directory" {
  mkdir -p doc/adr
  run _get_decision_record_path
  assert_output "doc/adr"
  assert_success
}

@test "01-03 Find basic doc/decision_records directory" {
  mkdir -p doc/decision_records
  run _get_decision_record_root
  assert_output "$BATS_TEST_TMPDIR"
  assert_success
}

@test "01-03a Find basic doc/decision_records directory" {
  mkdir -p doc/decision_records
  run _get_decision_record_path
  assert_output "doc/decision_records"
  assert_success
}

@test "01-04 Identify broken find configured decision_records directory using .adr-dir" {
  echo "decision_records" > .adr-dir
  run _get_decision_record_root
  assert_output --partial '[ Error ]: No decision records root found. Have you run `'
  assert_output --partial ' init`?'
  assert_failure
}

@test "01-05 Identify broken find configured decision_records directory using .decisionrecords-config" {
  echo "records=decision_records" > .decisionrecords-config
  run _get_decision_record_root
  assert_output --partial '[ Error ]: No decision records root found. Have you run `'
  assert_output --partial ' init`?'
  assert_failure
}

@test "01-06 Identify empty broken find configured decision_records directory using .decisionrecords-config" {
  echo "" > .decisionrecords-config
  run _get_decision_record_root
  assert_output --partial '[ Error ]: No decision records root found. Have you run `'
  assert_output --partial ' init`?'
  assert_failure
}

@test "01-07 Identify empty working find configured decision_records directory using .decisionrecords-config" {
  echo "" > .decisionrecords-config
  mkdir -p doc/decision_records
  run _get_decision_record_root
  assert_output "$BATS_TEST_TMPDIR"
  assert_success
}

@test "01-07a Identify empty working find configured decision_records directory using .decisionrecords-config" {
  echo "" > .decisionrecords-config
  mkdir -p doc/decision_records
  run _get_decision_record_path
  assert_output "doc/decision_records"
  assert_success
}

@test "01-08 Find configured decision_records directory using .adr-dir" {
  mkdir -p decision_records
  echo "decision_records" > .adr-dir
  run _get_decision_record_root
  assert_output "$BATS_TEST_TMPDIR"
  assert_success
}

@test "01-08a Find configured decision_records directory using .adr-dir" {
  mkdir -p decision_records
  echo "decision_records" > .adr-dir
  run _get_decision_record_path
  assert_output "decision_records"
  assert_success
}

@test "01-09 Find configured decision_records directory using .decisionrecords-config" {
  mkdir -p decision_records
  echo "records=decision_records" > .decisionrecords-config
  run _get_decision_record_root
  assert_output "$BATS_TEST_TMPDIR"
  assert_success
}

@test "01-09a Find configured decision_records directory using .decisionrecords-config" {
  mkdir -p decision_records
  echo "records=decision_records" > .decisionrecords-config
  run _get_decision_record_path
  assert_output "decision_records"
  assert_success
}