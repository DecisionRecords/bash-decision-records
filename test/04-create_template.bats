#!/usr/bin/env ./libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "../decision-records.sh"
  mkdir -p "$BATS_TEST_TMPDIR/doc/decision_records/.templates"
  cp templates/* "$BATS_TEST_TMPDIR/doc/decision_records/.templates"
  cp templates/template.en.md "$BATS_TEST_TMPDIR/doc/decision_records/.templates/template.md"
  cd "$BATS_TEST_TMPDIR"
}

@test "04-01 Find the next record reference with no files in the directory" {
  run _get_next_ref
  assert_output "1:0001"
  assert_success
}

@test "04-02 Find the next record reference with one file in the directory" {
  touch doc/decision_records/0001-temp.md
  run _get_next_ref
  assert_output "2:0002"
  assert_success
}

@test "04-03 Find the next record reference with two files in the directory" {
  touch doc/decision_records/0001-temp.md doc/decision_records/0002-temp.md
  run _get_next_ref
  assert_output "3:0003"
  assert_success
}

@test "04-04 Making slug strings" {
  run _make_slug 'Aa£ B#b % Cc/ Zz., 15&9'
  assert_output "aa-b-b-cc-zz-15-9"
  assert_success
}

@test "04-05 Trying to create a record with no title will fail" {
  run create_record
  assert_output '[ Error ]: To create a record, you must at least specify a title. Unable to proceed.'
  assert_failure
}

@test "04-06 Trying to create a record with a title will succeed" {
  run create_record "Some Title"
  assert_output "0001-some-title.md"
  assert_success
}

@test "04-07 Creating a second record with a title will succeed" {
  run create_record "Some Title"
  assert_output "0001-some-title.md"
  assert_success
  run create_record "Some other title"
  assert_output "0002-some-other-title.md"
  assert_success
}

@test "04-08 Creating a record with a non-default template will succeed and contain the right language." {
  echo "# KO" > "$BATS_TEST_TMPDIR/doc/decision_records/.templates/template.ko.md"
  echo "language=ko_KR" > .decisionrecords-config
  run create_record "Some Title"
  assert_output "0001-some-title.md"
  assert_success
  run cat "doc/decision_records/0001-some-title.md"
  assert_output "# KO"
}

@test "04-09 Creating a record contains expected text" {
  DR_DATE="1970-01-01"
  run create_record "Test"
  assert_output "0001-test.md"
  assert_success
  run cat "doc/decision_records/0001-test.md"
  assert_output --partial '# 1. Test'
  assert_output --partial 'Date: 1970-01-01'
  assert_output --partial '## Status'
  assert_output --partial 'Accepted'
  assert_output --partial '## Context'
  assert_output --partial 'This is the context.'
  assert_output --partial '## Decision'
  assert_output --partial 'This is the decision that was made.'
  assert_output --partial '## Consequence'
  assert_output --partial 'This is the consequence of the decision.'
}

@test "04-10 Creating a proposed record contains expected text" {
  DR_DATE="1970-01-01"
  create_record -P Test
  run cat "doc/decision_records/0001-test.md"
  assert_output --partial '# 1. Test'
  assert_output --partial 'Date: 1970-01-01'
  assert_output --partial '## Status'
  assert_output --partial 'Proposed'
  assert_output --partial '## Context'
  assert_output --partial 'This is the context.'
  assert_output --partial '## Decision'
  assert_output --partial 'This is the decision that was made.'
  assert_output --partial '## Consequence'
  assert_output --partial 'This is the consequence of the decision.'
  assert_success
}

@test "04-11 Creating a superseded record contains expected text" {
  DR_DATE="1970-01-01"
  run create_record 0411
  assert_success
  run create_record -s 1 0411
  assert_success
  run cat "doc/decision_records/0001-0411.md"
  assert_success
  assert_output --partial '# 1. 0411'
  assert_output --partial 'Date: 1970-01-01'
  assert_output --partial '## Status'
  assert_output --partial 'Superseded by [2. 0411](0002-0411.md)'
  assert_output --partial '## Context'
  assert_output --partial 'This is the context.'
  assert_output --partial '## Decision'
  assert_output --partial 'This is the decision that was made.'
  assert_output --partial '## Consequence'
  assert_output --partial 'This is the consequence of the decision.'
  run cat "doc/decision_records/0002-0411.md"
  assert_success
  assert_output --partial '# 2. 0411'
  assert_output --partial 'Date: 1970-01-01'
  assert_output --partial '## Status'
  assert_output --partial 'Approved'
  assert_output --partial 'Supersedes [1. 0411](0001-0411.md)'
  assert_output --partial '## Context'
  assert_output --partial 'This is the context.'
  assert_output --partial '## Decision'
  assert_output --partial 'This is the decision that was made.'
  assert_output --partial '## Consequence'
  assert_output --partial 'This is the consequence of the decision.'
}
