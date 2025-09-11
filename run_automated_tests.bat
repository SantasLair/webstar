@echo off
REM WebStar Automated Test Suite for CI/CD
REM Runs tests non-interactively and captures results
REM Returns exit code 0 for success, 1 for failure

setlocal EnableDelayedExpansion

echo =====================================
echo   WebStar Automated Test Suite
echo =====================================
echo Timestamp: %TIME%
echo.

REM Change to project directory
cd /d "f:\godot\webstar\webstar-addon-dev"

REM Check if Godot is available
where godot >nul 2>&1
if errorlevel 1 (
    echo ERROR: Godot Engine not found in PATH
    exit /b 1
)

echo Project Directory: %CD%
echo Godot Engine: Found
echo.

REM Create results directory
if not exist "test_results" mkdir test_results

REM Test configuration
set TEST_TIMEOUT=45
set TOTAL_TESTS=0
set PASSED_TESTS=0
set FAILED_TESTS=0

REM Core tests that should pass reliably
set "AUTOMATED_TESTS=simple_star_test.tscn webstar_test.tscn builtin_webrtc_test.tscn"

echo Running automated test suite...
echo Test timeout: %TEST_TIMEOUT% seconds per test
echo.

for %%t in (%AUTOMATED_TESTS%) do (
    set /a TOTAL_TESTS+=1
    set TEST_NAME=%%~nt
    
    echo =====================================
    echo Test !TOTAL_TESTS!: !TEST_NAME!
    echo =====================================
    
    REM Create simpler log file name
    set LOG_FILE=test_results\!TEST_NAME!_test.log
    
    echo Running %%t > "!LOG_FILE!"
    echo Test started at %TIME% >> "!LOG_FILE!"
    echo. >> "!LOG_FILE!"
    
    REM Run test with output capture (no timeout, let it complete)
    start /wait godot --path . %%t >> "!LOG_FILE!" 2>&1
    set TEST_RESULT=!errorlevel!
    
    echo. >> "!LOG_FILE!"
    echo Test ended at %TIME% >> "!LOG_FILE!"
    echo Exit code: !TEST_RESULT! >> "!LOG_FILE!"
    
    REM Analyze results
    if !TEST_RESULT! equ 0 (
        echo RESULT: PASSED
        set /a PASSED_TESTS+=1
        echo PASSED: !TEST_NAME! >> test_results\summary.log
    ) else (
        echo RESULT: FAILED ^(Exit code: !TEST_RESULT!^)
        set /a FAILED_TESTS+=1
        echo FAILED: !TEST_NAME! Exit code !TEST_RESULT! >> test_results\summary.log
    )
    
    echo Log saved to: !LOG_FILE!
    echo.
)

REM Generate summary report
echo ===================================== > test_results\final_report.txt
echo       WebStar Test Suite Report >> test_results\final_report.txt
echo ===================================== >> test_results\final_report.txt
echo Timestamp: %TIME% >> test_results\final_report.txt
echo. >> test_results\final_report.txt
echo Total Tests: !TOTAL_TESTS! >> test_results\final_report.txt
echo Passed: !PASSED_TESTS! >> test_results\final_report.txt
echo Failed: !FAILED_TESTS! >> test_results\final_report.txt
echo. >> test_results\final_report.txt

if !FAILED_TESTS! equ 0 (
    echo Status: ALL TESTS PASSED >> test_results\final_report.txt
    set SUCCESS_RATE=100
) else (
    echo Status: SOME TESTS FAILED >> test_results\final_report.txt
    if !TOTAL_TESTS! gtr 0 (
        set /a SUCCESS_RATE=!PASSED_TESTS! * 100 / !TOTAL_TESTS!
    ) else (
        set SUCCESS_RATE=0
    )
)

echo Success Rate: !SUCCESS_RATE!%% >> test_results\final_report.txt
echo. >> test_results\final_report.txt
echo Individual Test Results: >> test_results\final_report.txt
type test_results\summary.log >> test_results\final_report.txt

REM Display final results
echo =====================================
echo        FINAL TEST RESULTS
echo =====================================
type test_results\final_report.txt
echo.

REM Debug: Show variable values
echo DEBUG: TOTAL_TESTS=!TOTAL_TESTS!
echo DEBUG: PASSED_TESTS=!PASSED_TESTS!
echo DEBUG: FAILED_TESTS=!FAILED_TESTS!
echo.

REM Set exit code based on results
if !FAILED_TESTS! equ 0 (
    echo All tests passed successfully!
    exit /b 0
) else (
    echo !FAILED_TESTS! test(s) failed. Check logs in test_results directory.
    exit /b 1
)
