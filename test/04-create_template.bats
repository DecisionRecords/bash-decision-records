#!/usr/bin/env ./libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "../decision-records.sh"
  mkdir -p "$BATS_TEST_TMPDIR/doc/decision_records/.templates"
  cp templates/* "$BATS_TEST_TMPDIR/doc/decision_records/.templates"
  cp templates/template.en.md "$BATS_TEST_TMPDIR/doc/decision_records/.templates/template.md"
  cd "$BATS_TEST_TMPDIR"
  DR_DATE="1970-01-01"
  VISUAL=true
}

teardown() {
  cd /
  rm -Rf "$BATS_TEST_TMPDIR"
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
  run _make_slug 'Aa B#b % Cc/ Zz., 15&9'
  assert_output "aa-b-b-cc-zz-15-9"
  assert_success
}

@test "04-05 Trying to create a record with no title will fail" {
  run create_record
  assert_output '[ Error ]: To create a record, you must at least specify a title. Unable to proceed.'
  assert_failure
}

@test "04-06 Trying to create a record with a title will succeed" {
  DEBUG_FILENAME=1
  run create_record "Some Title"
  assert_output "0001-some-title.md"
  assert_success
}

@test "04-07 Creating a second record with a title will succeed" {
  DEBUG_FILENAME=1
  run create_record "Some Title"
  assert_output "0001-some-title.md"
  assert_success
  run create_record "Some other title"
  assert_output "0002-some-other-title.md"
  assert_success
}

@test "04-08 Creating a record with a non-default template will succeed and contain the right language." {
  DEBUG_FILENAME=1
  echo "# KO" > "$BATS_TEST_TMPDIR/doc/decision_records/.templates/template.ko.md"
  echo "language=ko_KR" > .decisionrecords-config
  run create_record "Some Title"
  assert_output "0001-some-title.md"
  assert_success
  run cat "doc/decision_records/0001-some-title.md"
  assert_output "# KO"
}

@test "04-09 Creating a record contains expected text" {
  DEBUG_FILENAME=1
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
  DEBUG_FILECONTENT=1
  run create_record a0411
  assert_success
  assert_output - <<EOF
# 1. a0411

Date: 1970-01-01

## Status

Accepted

## Context

This is the context.

## Decision

This is the decision that was made.

## Consequence

This is the consequence of the decision.
EOF
  run create_record -s 1 b0411
  assert_success
  assert_output - <<EOF
# 2. b0411

Date: 1970-01-01

## Status

Accepted
Supersedes [1. a0411](0001-a0411.md)

## Context

This is the context.

## Decision

This is the decision that was made.

## Consequence

This is the consequence of the decision.
EOF
  run cat "doc/decision_records/0001-a0411.md"
  assert_success
  assert_output - <<EOF
# 1. a0411

Date: 1970-01-01

## Status

Accepted
Superseded by [2. b0411](0002-b0411.md)

## Context

This is the context.

## Decision

This is the decision that was made.

## Consequence

This is the consequence of the decision.
EOF
  run create_record -s 1 c0411
  assert_output - <<EOF
# 3. c0411

Date: 1970-01-01

## Status

Accepted
Supersedes [1. a0411](0001-a0411.md)

## Context

This is the context.

## Decision

This is the decision that was made.

## Consequence

This is the consequence of the decision.
EOF
  run cat "doc/decision_records/0001-a0411.md"
  assert_success
  assert_output - <<EOF
# 1. a0411

Date: 1970-01-01

## Status

Accepted
Superseded by [3. c0411](0003-c0411.md)
Superseded by [2. b0411](0002-b0411.md)

## Context

This is the context.

## Decision

This is the decision that was made.

## Consequence

This is the consequence of the decision.
EOF
}

@test "04-12 Creating a foreign language record contains expected text" {
  # LOG_LEVEL=8
  DEBUG_FILECONTENT=1
  echo "language=de-DE" > .decisionrecords-config
  run create_record a0412
  assert_success
  assert_output - <<EOF
---
title: a0412
number: 1
date: 1970-01-01
---

Datum: {{ date }}

## Status

Akzeptiert

## Kontext

Dies ist der Kontext.

## Entscheidung

Eine Entscheidung getroffen haben.

## Konsequenz

Dies ist die Folge der Entscheidung.
EOF
  run create_record -d 1 b0412
  assert_success
  assert_output - <<EOF
---
title: b0412
number: 2
date: 1970-01-01
---

Datum: {{ date }}

## Status

Akzeptiert
Veraltet [1. a0412](0001-a0412.md)

## Kontext

Dies ist der Kontext.

## Entscheidung

Eine Entscheidung getroffen haben.

## Konsequenz

Dies ist die Folge der Entscheidung.
EOF
  run cat "doc/decision_records/0001-a0412.md"
  assert_success
  assert_output - <<EOF
---
title: a0412
number: 1
date: 1970-01-01
---

Datum: {{ date }}

## Status

Akzeptiert
Veraltet von [2. b0412](0002-b0412.md)

## Kontext

Dies ist der Kontext.

## Entscheidung

Eine Entscheidung getroffen haben.

## Konsequenz

Dies ist die Folge der Entscheidung.
EOF

}