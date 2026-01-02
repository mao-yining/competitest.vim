@echo off

REM Script to run the unit-tests for the CompetiTest.Vim plugin on MS-Windows

SETLOCAL
SET VIMPRG="vim.exe"
SET VIM_CMD=%VIMPRG% -u NONE -U NONE -i NONE --noplugin -N --not-a-term
set TESTS=commands_tests.vim receive_tests.vim

REM Main executn
for %%f in (%TESTS%) do (
  call :RunTestsInFile %%f
  if errorlevel 1 (
    echo ERROR: Test execution failed.
    exit /b %errorlevel%
  )
)

echo SUCCESS: All the tests passed.
exit /b 0

REM Test function definition
:RunTestsInFile
setlocal
set testfile=%~1
echo Running tests in %testfile%

%VIM_CMD% -c "let g:TestName='%testfile%'" -S launcher.vim

if not exist results.txt (
  echo ERROR: Test results file 'results.txt' is not found.
  exit /b 2
)

echo Unit test results
type results.txt

findstr /I /C:"FAIL" results.txt > nul 2>&1
if %errorlevel% equ 0 (
  echo ERROR: Some test in %testfile% failed.
  exit /b 3
)

echo SUCCESS: All the tests in %testfile% passed.
endlocal
exit /b 0
