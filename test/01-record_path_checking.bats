#!/usr/bin/env ./libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "../decision-records.sh"
  # LOG_LEVEL=255
}

@test "01-01 No valid directories found" {
  cd "$BATS_TEST_TMPDIR"
  run find_root_path
  echo "Status, $status. Actual output:"
  echo "$output"
  [ "${output:0:57}" == '[ Error ]: No decision records root found. Have you run `' ]
  [ "${output: -7}" == ' init`?' ]
  [ "$status" -eq 1 ]
}

@test "01-02 Find basic doc/adr directory" {
  cd "$BATS_TEST_TMPDIR"
  mkdir -p doc/adr
  run find_root_path
  echo "Status, $status. Actual output:"
  echo "$output"
  [ "$output" == "$BATS_TEST_TMPDIR" ]
  [ "$status" -eq 0 ]
}

@test "01-03 Find basic doc/decision_records directory" {
  cd "$BATS_TEST_TMPDIR"
  mkdir -p doc/decision_records
  run find_root_path
  echo "Status, $status. Actual output:"
  echo "$output"
  [ "$output" == "$BATS_TEST_TMPDIR" ]
  [ "$status" -eq 0 ]
}

@test "01-04 Identify broken find configured decision_records directory using .adr-dir" {
  cd "$BATS_TEST_TMPDIR"
  echo "decision_records" > .adr-dir
  run find_root_path
  echo "Status, $status. Actual output:"
  echo "$output"
  [ "${output:0:57}" == '[ Error ]: No decision records root found. Have you run `' ]
  [ "${output: -7}" == ' init`?' ]
  [ "$status" -eq 1 ]
}

@test "01-05 Identify broken find configured decision_records directory using .decisionrecords-config" {
  cd "$BATS_TEST_TMPDIR"
  echo "records=decision_records" > .decisionrecords-config
  run find_root_path
  echo "Status, $status. Actual output:"
  echo "$output"
  [ "${output:0:57}" == '[ Error ]: No decision records root found. Have you run `' ]
  [ "${output: -7}" == ' init`?' ]
  [ "$status" -eq 1 ]
}

@test "01-06 Identify empty broken find configured decision_records directory using .decisionrecords-config" {
  cd "$BATS_TEST_TMPDIR"
  echo "" > .decisionrecords-config
  run find_root_path
  echo "Status, $status. Actual output:"
  echo "$output"
  [ "${output:0:57}" == '[ Error ]: No decision records root found. Have you run `' ]
  [ "${output: -7}" == ' init`?' ]
  [ "$status" -eq 1 ]
}

@test "01-07 Identify empty working find configured decision_records directory using .decisionrecords-config" {
  cd "$BATS_TEST_TMPDIR"
  echo "" > .decisionrecords-config
  mkdir -p doc/decision_records
  run find_root_path
  echo "Status, $status. Actual output:"
  echo "$output"
  [ "$output" == "$BATS_TEST_TMPDIR" ]
  [ "$status" -eq 0 ]
}

@test "01-08 Find configured decision_records directory using .adr-dir" {
  cd "$BATS_TEST_TMPDIR"
  mkdir -p decision_records
  echo "decision_records" > .adr-dir
  run find_root_path
  echo "Status, $status. Actual output:"
  echo "$output"
  [ "$output" == "$BATS_TEST_TMPDIR" ]
  [ "$status" -eq 0 ]
}

@test "01-09 Find configured decision_records directory using .decisionrecords-config" {
  cd "$BATS_TEST_TMPDIR"
  mkdir -p decision_records
  echo "records=decision_records" > .decisionrecords-config
  run find_root_path
  echo "Status, $status. Actual output:"
  echo "$output"
  [ "$output" == "$BATS_TEST_TMPDIR" ]
  [ "$status" -eq 0 ]
}