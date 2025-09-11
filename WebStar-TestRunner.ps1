# WebStar Test Suite - Clean PowerShell Version
# Simple and reliable test runner

param(
    [string]$TestType = "automated",
    [int]$TimeoutSeconds = 45,
    [string]$SpecificTest = ""
)

$ErrorActionPreference = "Continue"

# Test suites
$TestSuites = @{
    "automated" = @("simple_star_test.tscn", "webstar_test.tscn", "builtin_webrtc_test.tscn")
    "webrtc" = @("builtin_webrtc_test.tscn", "p2p_webrtc_test.tscn", "webrtc_validation_test.tscn")
    "networking" = @("high_level_networking_test.tscn", "multi_client_test.tscn", "star_topology_test.tscn")
    "all" = @("simple_star_test.tscn", "webstar_test.tscn", "builtin_webrtc_test.tscn", "star_topology_test.tscn", "high_level_networking_test.tscn")
}

$results = @{ Total = 0; Passed = 0; Failed = 0; Details = @() }

function Write-Header {
    param([string]$Text)
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan  
    Write-Host "=====================================" -ForegroundColor Cyan
}

function Test-Prerequisites {
    # Check Godot
    try {
        $null = Get-Command godot -ErrorAction Stop
        Write-Host "SUCCESS: Godot Engine found" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Godot not found in PATH" -ForegroundColor Red
        exit 1
    }

    # Check project
    $projectDir = "f:\godot\webstar\webstar-addon-dev"
    if (-not (Test-Path $projectDir)) {
        Write-Host "ERROR: Project not found: $projectDir" -ForegroundColor Red
        exit 1
    }

    Set-Location $projectDir
    Write-Host "Project: $((Get-Location).Path)" -ForegroundColor Blue
    
    # Create results dir
    if (-not (Test-Path "test_results")) {
        New-Item -ItemType Directory -Path "test_results" | Out-Null
    }
}

function Run-Test {
    param([string]$SceneFile, [int]$TestNum)
    
    $testName = [System.IO.Path]::GetFileNameWithoutExtension($SceneFile)
    
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "Test $TestNum`: $testName" -ForegroundColor White
    Write-Host "=====================================" -ForegroundColor Cyan

    if (-not (Test-Path $SceneFile)) {
        Write-Host "SKIPPED: Scene not found - $SceneFile" -ForegroundColor Yellow
        return "SKIPPED"
    }

    try {
        Write-Host "Running test..." -ForegroundColor Yellow
        $process = Start-Process -FilePath "godot" -ArgumentList "--path", ".", $SceneFile -PassThru -Wait -NoNewWindow
        $exitCode = $process.ExitCode
        
        if ($exitCode -eq 0) {
            Write-Host "PASSED" -ForegroundColor Green
            return "PASSED"
        } else {
            Write-Host "FAILED (Exit code: $exitCode)" -ForegroundColor Red
            return "FAILED"
        }
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return "FAILED"
    }
    finally {
        Write-Host ""
    }
}

# Main execution
Clear-Host
Write-Header "WebStar Test Suite"
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "Test Type: $TestType" -ForegroundColor Blue
Write-Host ""

Test-Prerequisites

# Determine tests to run
$testsToRun = @()
if ($SpecificTest) {
    $testsToRun = @("$SpecificTest.tscn")
} elseif ($TestSuites.ContainsKey($TestType)) {
    $testsToRun = $TestSuites[$TestType]
} else {
    Write-Host "Unknown test type: $TestType" -ForegroundColor Red
    Write-Host "Available: $($TestSuites.Keys -join ', ')" -ForegroundColor Yellow
    exit 1
}

Write-Host "Running $($testsToRun.Count) tests:" -ForegroundColor White
foreach ($test in $testsToRun) {
    Write-Host "  - $test" -ForegroundColor Gray
}
Write-Host ""

# Run tests
foreach ($test in $testsToRun) {
    $results.Total++
    $result = Run-Test -SceneFile $test -TestNum $results.Total
    
    switch ($result) {
        "PASSED" { $results.Passed++ }
        "FAILED" { $results.Failed++ }
    }
    
    $results.Details += @{
        Name = [System.IO.Path]::GetFileNameWithoutExtension($test)
        Result = $result
    }
}

# Final report
Write-Header "FINAL RESULTS"
Write-Host "Total Tests: $($results.Total)" -ForegroundColor White
Write-Host "Passed: $($results.Passed)" -ForegroundColor Green
Write-Host "Failed: $($results.Failed)" -ForegroundColor Red

if ($results.Failed -eq 0) {
    $successRate = if ($results.Total -gt 0) { [math]::Round(($results.Passed / $results.Total) * 100, 1) } else { 0 }
    Write-Host "Success Rate: $successRate%" -ForegroundColor Green
    Write-Host ""
    Write-Host "ALL TESTS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "$($results.Failed) test(s) failed" -ForegroundColor Red
    exit 1
}
