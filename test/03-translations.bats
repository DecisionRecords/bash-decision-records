#!/usr/bin/env ./libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "../decision-records.sh"
  cd "$BATS_TEST_TMPDIR"
  mkdir -p doc/decision_records
}

@test "03-01 Test that no language results in exact string replacement" {
  run _t "This is a test"
  assert_output "This is a test"
}

@test "03-02 Test that specifying German language but without a string replacement results in exact string replacement" {
  echo "language=de_DE" > .decisionrecords-config
  run _t "This is a test"
  assert_output "This is a test"
}

@test "03-03 Test that specifying German language with a string replacement results in the replaced string" {
  echo "language=de_DE" > .decisionrecords-config
  run _t "Accepted"
  assert_output "Akzeptiert"
}

@test "03-04 Test that specifying French language with a string replacement results in the replaced string" {
  echo "language=fr_CA" > .decisionrecords-config
  run _t 'Superseded by'
  assert_output "Remplacé par #"
}