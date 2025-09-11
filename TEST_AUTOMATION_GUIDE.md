# WebStar Test Automation Guide

## Overview
Two automated test runners are available for the WebStar addon:

### 1. Windows Batch File (`run_automated_tests.bat`)
- **Location**: `f:\godot\webstar\run_automated_tests.bat`
- **Usage**: Double-click or run from command line
- **Features**: 
  - Works with Windows Command Prompt
  - Simple timeout handling
  - Creates detailed logs
  - Generates test reports

### 2. PowerShell Script (`run-automated-tests.ps1`)
- **Location**: `f:\godot\webstar\run-automated-tests.ps1`
- **Usage**: `powershell -ExecutionPolicy Bypass -File .\run-automated-tests.ps1`
- **Features**:
  - Better error handling
  - Colorized output
  - More robust process management
  - Timeout parameter support

## Test Suite Configuration

Both scripts run the following core tests:
1. **simple_star_test.tscn** - Basic star topology validation
2. **webstar_test.tscn** - Comprehensive WebStar functionality
3. **builtin_webrtc_test.tscn** - Built-in WebRTC validation

## Running Tests

### Option 1: Windows Batch (Recommended for Windows)
```batch
cd f:\godot\webstar
.\run_automated_tests.bat
```

### Option 2: PowerShell (Better for CI/CD)
```powershell
cd f:\godot\webstar
powershell -ExecutionPolicy Bypass -File .\run-automated-tests.ps1
```

### Option 3: With Custom Timeout (PowerShell only)
```powershell
.\run-automated-tests.ps1 -TimeoutSeconds 60
```

## Test Results

Results are saved to `webstar-addon-dev/test_results/`:
- `final_report.txt` - Summary of all tests
- `{test_name}_test.log` - Individual test logs
- `summary.log` - Quick results overview

## Expected Output

### Successful Run
```
=====================================
  WebStar Automated Test Suite
=====================================

Test 1: simple_star_test
RESULT: PASSED

Test 2: webstar_test  
RESULT: PASSED

Test 3: builtin_webrtc_test
RESULT: PASSED

Total Tests: 3
Passed: 3
Failed: 0
Success Rate: 100%

All tests passed successfully!
```

### Test Failures
If tests fail, check the individual log files for detailed error information.

## Prerequisites

1. **Godot Engine** must be in your system PATH
2. **WebStar project** must be at `f:\godot\webstar\webstar-addon-dev`
3. **Network access** for signaling server tests (webstar_test.tscn)

## Troubleshooting

### "Godot Engine not found in PATH"
Add Godot to your system PATH or copy the Godot executable to the project directory.

### "Project directory not found"
Ensure the WebStar addon project is located at the expected path.

### Tests timeout
Increase timeout value in PowerShell version or modify TEST_TIMEOUT in batch file.

### Network-dependent tests fail
The `webstar_test.tscn` requires internet access to connect to the signaling server at `dev.webstar.santaslair.net`.

## Integration with CI/CD

For automated builds, use the PowerShell version with error handling:

```powershell
try {
    & ".\run-automated-tests.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Tests failed with exit code $LASTEXITCODE"
        exit 1
    }
    Write-Host "All tests passed!"
} catch {
    Write-Error "Test execution failed: $($_.Exception.Message)"
    exit 1
}
```

## Current Test Status
- ✅ All compilation errors fixed
- ✅ WebStar addon fully functional
- ✅ All 3 test scenarios passing (100% success rate)
- ✅ Star topology validated
- ✅ WebRTC connectivity confirmed
- ✅ Signaling server integration working
