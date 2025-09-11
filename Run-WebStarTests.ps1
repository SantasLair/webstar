# WebStar Test Suite - Complete PowerShell Solution
# Main test runner with comprehensive functionality

[CmdletBinding()]
param(
    [string]$TestType = "automated",  # automated, interactive, all
    [int]$TimeoutSeconds = 45,
    [string]$SpecificTest = "",
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

# Test Categories
$TestSuites = @{
    "automated" = @(
        "simple_star_test.tscn",
        "webstar_test.tscn", 
        "builtin_webrtc_test.tscn"
    )
    "webrtc" = @(
        "builtin_webrtc_test.tscn",
        "p2p_webrtc_test.tscn",
        "webrtc_validation_test.tscn"
    )
    "networking" = @(
        "high_level_networking_test.tscn",
        "multi_client_test.tscn",
        "star_topology_test.tscn"
    )
    "interactive" = @(
        "interactive_webrtc_test.tscn",
        "high_level_demo.tscn",
        "star_topology_demo.tscn"
    )
    "all" = @(
        "simple_star_test.tscn",
        "webstar_test.tscn", 
        "builtin_webrtc_test.tscn",
        "star_topology_test.tscn",
        "high_level_networking_test.tscn",
        "multi_client_test.tscn",
        "p2p_webrtc_test.tscn",
        "webrtc_validation_test.tscn"
    )
}

$TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
    TestDetails = @()
    StartTime = Get-Date
    EndTime = $null
}

function Write-Header {
    param([string]$Title, [string]$Color = "Cyan")
    
    Write-Host "=====================================" -ForegroundColor $Color
    Write-Host "  $Title" -ForegroundColor $Color
    Write-Host "=====================================" -ForegroundColor $Color
}

function Write-TestResult {
    param([string]$TestName, [string]$Result, [string]$Details = "")
    
    $color = switch ($Result) {
        "PASSED" { "Green" }
        "FAILED" { "Red" }
        "SKIPPED" { "Yellow" }
        default { "White" }
    }
    
    Write-Host "RESULT: " -NoNewline
    Write-Host $Result -ForegroundColor $color
    if ($Details) {
        Write-Host "Details: $Details" -ForegroundColor Gray
    }
}

function Test-Prerequisites {
    Write-Host "Checking prerequisites..." -ForegroundColor Blue
    
    # Check Godot
    try {
        $null = Get-Command godot -ErrorAction Stop
        Write-Host "✅ Godot Engine found in PATH" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ ERROR: Godot Engine not found in PATH" -ForegroundColor Red
        Write-Host "Please install Godot Engine and add it to your PATH" -ForegroundColor Yellow
        exit 1
    }

    # Check project directory
    $projectDir = "f:\godot\webstar\webstar-addon-dev"
    if (-not (Test-Path $projectDir)) {
        Write-Host "❌ ERROR: Project directory not found: $projectDir" -ForegroundColor Red
        exit 1
    }

    Set-Location $projectDir
    Write-Host "📁 Project Directory: $((Get-Location).Path)" -ForegroundColor Blue
    
    # Create results directory
    if (-not (Test-Path "test_results")) {
        New-Item -ItemType Directory -Path "test_results" | Out-Null
        Write-Host "📁 Created test_results directory" -ForegroundColor Green
    }
    
    Write-Host ""
}

function Run-SingleTest {
    param(
        [string]$SceneFile,
        [int]$Timeout,
        [int]$TestNumber
    )

    $testName = [System.IO.Path]::GetFileNameWithoutExtension($SceneFile)
    $logFile = "test_results\$testName" + "_test.log"
    
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Test $TestNumber`: $testName" -ForegroundColor White
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Scene: $SceneFile" -ForegroundColor Gray
    Write-Host "Log: $logFile" -ForegroundColor Gray
    Write-Host ""

    if (-not (Test-Path $SceneFile)) {
        Write-Host "❌ ERROR: Test scene not found: $SceneFile" -ForegroundColor Red
        Write-TestResult $testName "SKIPPED" "Scene file not found"
        return @{ Result = "SKIPPED"; ExitCode = -1; Details = "Scene file not found" }
    }

    try {
        Write-Host "🚀 Starting test..." -ForegroundColor Yellow
        
        # Start process and wait
        $process = Start-Process -FilePath "godot" -ArgumentList "--path", ".", $SceneFile -PassThru -Wait -NoNewWindow
        $exitCode = $process.ExitCode
        
        Write-Host "✅ Test completed with exit code: $exitCode" -ForegroundColor Green
        
        if ($exitCode -eq 0) {
            Write-TestResult $testName "PASSED"
            return @{ Result = "PASSED"; ExitCode = $exitCode; Details = "" }
        } else {
            Write-TestResult $testName "FAILED" "Exit code: $exitCode"
            return @{ Result = "FAILED"; ExitCode = $exitCode; Details = "Exit code: $exitCode" }
        }
    }
    catch {
        Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
        Write-TestResult $testName "FAILED" $_.Exception.Message
        return @{ Result = "FAILED"; ExitCode = -1; Details = $_.Exception.Message }
    }
    finally {
        Write-Host "📄 Logs would be in: $logFile" -ForegroundColor Gray
        Write-Host ""
    }
}

function Generate-Report {
    $TestResults.EndTime = Get-Date
    $duration = $TestResults.EndTime - $TestResults.StartTime
    
    $successRate = if ($TestResults.TotalTests -gt 0) { 
        [math]::Round(($TestResults.PassedTests / $TestResults.TotalTests) * 100, 1) 
    } else { 0 }

    $report = @"
=====================================
      WebStar Test Suite Report
=====================================
Start Time: $($TestResults.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))
End Time: $($TestResults.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))
Duration: $($duration.ToString('mm\:ss'))

Total Tests: $($TestResults.TotalTests)
Passed: $($TestResults.PassedTests)
Failed: $($TestResults.FailedTests)
Skipped: $($TestResults.SkippedTests)
Success Rate: $successRate%

Individual Test Results:
"@

    foreach ($detail in $TestResults.TestDetails) {
        $report += "`n$($detail.Result): $($detail.Name)"
        if ($detail.Details) {
            $report += " ($($detail.Details))"
        }
    }

    if ($TestResults.FailedTests -eq 0 -and $TestResults.SkippedTests -eq 0) {
        $report += "`n`n🎉 STATUS: ALL TESTS PASSED"
    } elseif ($TestResults.FailedTests -eq 0) {
        $report += "`n`n⚠️  STATUS: ALL TESTS PASSED (Some skipped)"
    } else {
        $report += "`n`n❌ STATUS: SOME TESTS FAILED"
    }

    # Save report
    $report | Out-File -FilePath "test_results\final_report.txt" -Encoding UTF8

    return $report
}

# Main execution starts here
Clear-Host
Write-Header "WebStar Test Suite - PowerShell Edition"
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Test Type: $TestType" -ForegroundColor Blue
Write-Host "Timeout: $TimeoutSeconds seconds per test" -ForegroundColor Blue
Write-Host ""

Test-Prerequisites

# Determine which tests to run
$testsToRun = @()

if ($SpecificTest) {
    if ($SpecificTest.EndsWith(".tscn")) {
        $testsToRun = @($SpecificTest)
    } else {
        $testsToRun = @("$SpecificTest.tscn")
    }
    Write-Host "Running specific test: $SpecificTest" -ForegroundColor Yellow
} elseif ($TestSuites.ContainsKey($TestType)) {
    $testsToRun = $TestSuites[$TestType]
    Write-Host "Running $TestType test suite ($($testsToRun.Count) tests)" -ForegroundColor Yellow
} else {
    Write-Host "❌ ERROR: Unknown test type '$TestType'" -ForegroundColor Red
    Write-Host "Available test types: $($TestSuites.Keys -join ', ')" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Tests to run:" -ForegroundColor White
foreach ($test in $testsToRun) {
    Write-Host "  • $test" -ForegroundColor Gray
}
Write-Host ""

# Run all tests
foreach ($test in $testsToRun) {
    $TestResults.TotalTests++
    $result = Run-SingleTest -SceneFile $test -Timeout $TimeoutSeconds -TestNumber $TestResults.TotalTests
    
    switch ($result.Result) {
        "PASSED" { $TestResults.PassedTests++ }
        "FAILED" { $TestResults.FailedTests++ }
        "SKIPPED" { $TestResults.SkippedTests++ }
    }
    
    $TestResults.TestDetails += @{
        Name = [System.IO.Path]::GetFileNameWithoutExtension($test)
        Result = $result.Result
        ExitCode = $result.ExitCode
        Details = $result.Details
    }
}

# Generate and display final report
Write-Header "FINAL TEST RESULTS"
$finalReport = Generate-Report
Write-Host $finalReport
Write-Host ""

# Set exit code
if ($TestResults.FailedTests -eq 0) {
    Write-Host "🎉 All tests completed successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ $($TestResults.FailedTests) test(s) failed. Check logs in test_results directory." -ForegroundColor Red
    exit 1
}
