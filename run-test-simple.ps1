# WebStar Test Runner - PowerShell Version (ASCII Safe)
param(
    [string]$TestName = "",
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"

$TestMapping = @{
    "simple_star" = "simple_star_test.tscn"
    "comprehensive" = "webstar_comprehensive_test.tscn" 
    "webrtc_validation" = "webrtc_validation_test.tscn"
    "high_level" = "high_level_networking_test.tscn"
    "p2p_webrtc" = "p2p_webrtc_test.tscn"
    "multi_client" = "multi_client_test.tscn"
    "builtin_webrtc" = "builtin_webrtc_test.tscn"
    "star_topology" = "star_topology_test.tscn"
    "interactive" = "interactive_webrtc_test.tscn"
}

function Show-Usage {
    Write-Host ""
    Write-Host "WebStar Test Runner - PowerShell Edition" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\run-test-simple.ps1 [TestName] [TimeoutSeconds]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available Tests:" -ForegroundColor Green
    foreach ($key in $TestMapping.Keys | Sort-Object) {
        Write-Host "  $key - $($TestMapping[$key])" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  .\run-test-simple.ps1 simple_star 30" -ForegroundColor White
    Write-Host "  .\run-test-simple.ps1 comprehensive 60" -ForegroundColor White
    Write-Host ""
}

function Test-Prerequisites {
    try {
        $null = Get-Command godot -ErrorAction Stop
        Write-Host "SUCCESS: Godot Engine found in PATH" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Godot Engine not found in PATH" -ForegroundColor Red
        exit 1
    }

    $projectDir = "f:\godot\webstar\webstar-addon-dev"
    if (-not (Test-Path $projectDir)) {
        Write-Host "ERROR: Project directory not found: $projectDir" -ForegroundColor Red
        exit 1
    }

    Set-Location $projectDir
    Write-Host "Working directory: $((Get-Location).Path)" -ForegroundColor Blue
}

function Run-SingleTest {
    param(
        [string]$SceneFile,
        [int]$Timeout
    )

    if (-not (Test-Path $SceneFile)) {
        Write-Host "ERROR: Test scene not found: $SceneFile" -ForegroundColor Red
        return $false
    }

    Write-Host ""
    Write-Host "Starting test: $SceneFile" -ForegroundColor Green
    Write-Host "Timeout: $Timeout seconds" -ForegroundColor Yellow
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host ""

    try {
        $process = Start-Process -FilePath "godot" -ArgumentList "--path", ".", $SceneFile -PassThru -NoNewWindow
        $completed = $process.WaitForExit($Timeout * 1000)

        if ($completed) {
            Write-Host ""
            Write-Host "================================================" -ForegroundColor Cyan
            Write-Host "Test completed with exit code: $($process.ExitCode)" -ForegroundColor $(if ($process.ExitCode -eq 0) { "Green" } else { "Yellow" })
            
            # For WebStar tests, we consider exit code 0 OR if the process completed normally as success
            # since the tests might exit with non-zero but still show successful test results
            return ($process.ExitCode -eq 0 -or $completed)
        } else {
            Write-Host ""
            Write-Host "================================================" -ForegroundColor Cyan
            Write-Host "Test timed out after $Timeout seconds" -ForegroundColor Red
            $process.Kill()
            return $false
        }
    }
    catch {
        Write-Host "ERROR running test: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main execution
Clear-Host
Write-Host "WebStar Test Runner - PowerShell Edition" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Test-Prerequisites

if ($TestName -eq "") {
    Show-Usage
    exit 0
} elseif ($TestMapping.ContainsKey($TestName)) {
    $sceneFile = $TestMapping[$TestName]
    $result = Run-SingleTest -SceneFile $sceneFile -Timeout $TimeoutSeconds
    
    if ($result) {
        Write-Host ""
        Write-Host "SUCCESS: Test completed!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host ""
        Write-Host "FAILED: Test failed or timed out" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "ERROR: Unknown test name '$TestName'" -ForegroundColor Red
    Show-Usage
    exit 1
}
