#!/bin/bash
cd "$(dirname "$0")" || true
if [ DEBUG=1 ]
then
  libs/bats/bin/bats $(find *.bats -maxdepth 0 | sort) --no-tempdir-cleanup
else
  libs/bats/bin/bats $(find *.bats -maxdepth 0 | sort)
fi
