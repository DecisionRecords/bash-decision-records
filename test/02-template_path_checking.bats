#!/usr/bin/env ./libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
  source "../decision-records.sh"
  cd "$BATS_TEST_TMPDIR"
  mkdir -p doc/decision_records
}

@test "02-01 No configuration returns default template directory name which fails as it does not exist" {
  run decision_record_config_template_dir
  assert_output '[ Error ]: Template Directory `doc/decision_records/.templates` is missing. Unable to proceed.'
  assert_failure
}

@test "02-02 No configuration returns default template directory name" {
  mkdir -p doc/decision_records/.templates
  run decision_record_config_template_dir
  assert_output 'doc/decision_records/.templates'
  assert_success
}

@test "02-03 Configuration file changes default template directory name" {
  echo "templatedir=random" > .decisionrecords-config
  mkdir -p random
  run decision_record_config_template_dir
  assert_output "random"
  assert_success
}

@test "02-04 Empty Configuration file returns default template directory name" {
  touch .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  run decision_record_config_template_dir
  assert_output "doc/decision_records/.templates"
  assert_success
}

@test "02-05 No configuration returns default template file name which fails as it does not exist" {
  mkdir -p doc/decision_records/.templates
  run decision_record_config_template_file
  assert_output '[ Error ]: Template `doc/decision_records/.templates/template.md` is missing. Unable to proceed.'
  assert_failure
}

@test "02-06 No configuration returns default template file name" {
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.md
  run decision_record_config_template_file
  assert_output "template"
  assert_success
}

@test "02-07 Configuration file changes default template file name" {
  echo "template=random" > .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/random.md
  run decision_record_config_template_file
  assert_output "random"
  assert_success
}

@test "02-08 Empty Configuration file returns default template file name" {
  touch .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.md
  run decision_record_config_template_file
  assert_output "template"
  assert_success
}

@test "02-09 No configuration returns no specific template language" {
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.en_GB.md doc/decision_records/.templates/template.md
  run decision_record_config_template_language
  assert_output ""
  assert_success
}

@test "02-10 Configuration file changes default template language" {
  echo "language=ko_KR" > .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.en_GB.md doc/decision_records/.templates/template.ko_KR.md doc/decision_records/.templates/template.md
  run decision_record_config_template_language
  assert_output "ko_KR"
  assert_success
}

@test "02-11 Configuration file changes default template language, but reverts to region language if that is the only one available" {
  echo "language=ko_KR" > .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.en_GB.md doc/decision_records/.templates/template.ko.md doc/decision_records/.templates/template.md
  run decision_record_config_template_language
  assert_output "ko"
  assert_success
}

@test "02-12 Configuration file changes default template language, but reverts to no specific template language if these languages are not available" {
  echo "language=ko_KR" > .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.md
  run decision_record_config_template_language
  assert_output ""
  assert_success
}

@test "02-13 Empty Configuration file returns default template language" {
  touch .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.en_GB.md doc/decision_records/.templates/template.md
  run decision_record_config_template_language
  assert_output ""
  assert_success
}

@test "02-14 Empty Configuration file returns default template" {
  touch .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.en_GB.md doc/decision_records/.templates/template.md
  run get_template_path
  assert_output "doc/decision_records/.templates/template.md"
  assert_success
}

@test "02-15 Configuration file changes default template" {
  echo "language=ko_KR" > .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.en_GB.md doc/decision_records/.templates/template.ko_KR.md doc/decision_records/.templates/template.md
  run get_template_path
  assert_output "doc/decision_records/.templates/template.ko_KR.md"
  assert_success
}

@test "02-16 Configuration file changes default template, but reverts to region language if that is the only one available" {
  echo "language=ko_KR" > .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.en_GB.md doc/decision_records/.templates/template.ko.md doc/decision_records/.templates/template.md
  run get_template_path
  assert_output "doc/decision_records/.templates/template.ko.md"
  assert_success
}

@test "02-17 Configuration file changes default template language, but reverts to no specific template language if these languages are not available" {
  echo "language=ko_KR" > .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.md
  run get_template_path
  assert_output "doc/decision_records/.templates/template.md"
  assert_success
}

@test "02-18 Configuration file changes default template" {
  echo "template=random" > .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/random.md
  run get_template_path
  assert_output "doc/decision_records/.templates/random.md"
  assert_success
}

@test "02-19 Use different configuration file types" {
  echo "filetype=rst" > .decisionrecords-config
  mkdir -p doc/decision_records/.templates
  touch doc/decision_records/.templates/template.rst
  run get_template_path
  assert_output "doc/decision_records/.templates/template.rst"
  assert_success
}