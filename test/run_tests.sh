#!/bin/bash

# Script to run the unit-tests for the CompetiTest.Vim Vim plugin

VIMPRG=${VIMPRG:=$(which vim)}
if [ -z "$VIMPRG" ]; then
  echo "ERROR: vim (\$VIMPRG) is not found in PATH"
  exit 1
fi

VIM_CMD="$VIMPRG -u NONE -U NONE -i NONE --noplugin -N --not-a-term"

TESTS="commands_tests.vim"

RunTestsInFile() {
  testfile=$1
  echo "Running tests in $testfile"
  $VIM_CMD -c "let g:TestName='$testfile'" -S runner.vim

  if ! [ -f results.txt ]; then
    echo "ERROR: Test results file 'results.txt' is not found."
    exit 2
  fi

  cat results.txt

  if grep -qw FAIL results.txt; then
    echo "ERROR: Some test(s) in $testfile failed."
    exit 3
  fi

  echo "SUCCESS: All the tests in $testfile passed."
  echo
}

for testfile in $TESTS
do
  RunTestsInFile $testfile
done

echo "SUCCESS: All the tests passed."
exit 0

# vim: shiftwidth=2 softtabstop=2 noexpandtab
