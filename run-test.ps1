# WebStar Test Runner - PowerShell Version
# Provides better timeout and process control than batch files

param(
    [string]$TestName = "",
    [int]$TimeoutSeconds = 30
)

# Set error handling
$ErrorActionPreference = "Stop"

# Test name mapping
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
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\run-test.ps1 [TestName] [TimeoutSeconds]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Available Tests:" -ForegroundColor Green
    foreach ($key in $TestMapping.Keys | Sort-Object) {
        Write-Host "  $key" -ForegroundColor White -NoNewline
        Write-Host " - $($TestMapping[$key])" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Green
    Write-Host "  .\run-test.ps1 simple_star 30" -ForegroundColor White
    Write-Host "  .\run-test.ps1 comprehensive 60" -ForegroundColor White
    Write-Host ""
}

function Test-Prerequisites {
    # Check if Godot is available
    try {
        $null = Get-Command godot -ErrorAction Stop
        Write-Host "Godot Engine found in PATH" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Godot Engine not found in PATH" -ForegroundColor Red
        Write-Host "Please install Godot Engine and add it to your PATH" -ForegroundColor Yellow
        exit 1
    }

    # Check if we're in the right directory
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
        Write-Host "❌ ERROR: Test scene not found: $SceneFile" -ForegroundColor Red
        return $false
    }

    Write-Host ""
    Write-Host "🚀 Starting test: $SceneFile" -ForegroundColor Green
    Write-Host "⏱️  Timeout: $Timeout seconds" -ForegroundColor Yellow
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host ""

    try {
        # Start the Godot process
        $process = Start-Process -FilePath "godot" -ArgumentList "--path", ".", $SceneFile -PassThru -NoNewWindow

        # Wait for the process to complete or timeout
        $completed = $process.WaitForExit($Timeout * 1000)

        if ($completed) {
            Write-Host ""
            Write-Host "=" * 50 -ForegroundColor Cyan
            Write-Host "✅ Test completed with exit code: $($process.ExitCode)" -ForegroundColor Green
            return ($process.ExitCode -eq 0)
        } else {
            Write-Host ""
            Write-Host "=" * 50 -ForegroundColor Cyan
            Write-Host "⏰ Test timed out after $Timeout seconds" -ForegroundColor Yellow
            $process.Kill()
            return $false
        }
    }
    catch {
        Write-Host "❌ ERROR running test: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Run-AllTests {
    Write-Host ""
    Write-Host "🧪 Running WebStar Test Suite" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host ""

    $coreTests = @("simple_star", "comprehensive")
    $webrtcTests = @("builtin_webrtc", "p2p_webrtc", "webrtc_validation")
    $networkingTests = @("high_level", "multi_client")

    $totalTests = 0
    $passedTests = 0

    Write-Host "📋 CORE FUNCTIONALITY TESTS" -ForegroundColor Magenta
    Write-Host "----------------------------" -ForegroundColor Magenta
    
    foreach ($test in $coreTests) {
        $totalTests++
        $scene = $TestMapping[$test]
        Write-Host ""
        Write-Host "Test $totalTests - $test" -ForegroundColor White
        
        $result = Run-SingleTest -SceneFile $scene -Timeout $TimeoutSeconds
        if ($result) {
            $passedTests++
            Write-Host "✅ PASSED: $test" -ForegroundColor Green
        } else {
            Write-Host "❌ FAILED: $test" -ForegroundColor Red
        }
        
        Write-Host ""
        Read-Host "Press Enter to continue to next test"
    }

    Write-Host ""
    Write-Host "🌐 WEBRTC TESTS" -ForegroundColor Magenta
    Write-Host "----------------" -ForegroundColor Magenta
    
    foreach ($test in $webrtcTests) {
        $totalTests++
        $scene = $TestMapping[$test]
        Write-Host ""
        Write-Host "Test $totalTests - $test" -ForegroundColor White
        
        $result = Run-SingleTest -SceneFile $scene -Timeout $TimeoutSeconds
        if ($result) {
            $passedTests++
            Write-Host "✅ PASSED: $test" -ForegroundColor Green
        } else {
            Write-Host "❌ FAILED: $test" -ForegroundColor Red
        }
        
        Write-Host ""
        Read-Host "Press Enter to continue to next test"
    }

    Write-Host ""
    Write-Host "🔗 NETWORKING TESTS" -ForegroundColor Magenta
    Write-Host "--------------------" -ForegroundColor Magenta
    
    foreach ($test in $networkingTests) {
        $totalTests++
        $scene = $TestMapping[$test]
        Write-Host ""
        Write-Host "Test $totalTests - $test" -ForegroundColor White
        
        $result = Run-SingleTest -SceneFile $scene -Timeout $TimeoutSeconds
        if ($result) {
            $passedTests++
            Write-Host "✅ PASSED: $test" -ForegroundColor Green
        } else {
            Write-Host "❌ FAILED: $test" -ForegroundColor Red
        }
        
        Write-Host ""
        Read-Host "Press Enter to continue to next test"
    }

    # Final summary
    $successRate = [math]::Round(($passedTests / $totalTests) * 100, 1)
    
    Write-Host ""
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host "📊 FINAL TEST RESULTS" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: $passedTests" -ForegroundColor Green
    Write-Host "Failed: $($totalTests - $passedTests)" -ForegroundColor Red
    Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } else { "Yellow" })
    Write-Host ""
    
    if ($passedTests -eq $totalTests) {
        Write-Host "🎉 ALL TESTS PASSED!" -ForegroundColor Green
    } elseif ($successRate -ge 80) {
        Write-Host "✅ Most tests passed - WebStar is functioning well" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Several tests failed - Check WebStar configuration" -ForegroundColor Yellow
    }
}

# Main execution
Clear-Host
Write-Host "🌟 WebStar Test Runner - PowerShell Edition" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

Test-Prerequisites

if ($TestName -eq "") {
    Show-Usage
    $choice = Read-Host "`nRun all tests? (y/N)"
    if ($choice -eq "y" -or $choice -eq "Y") {
        Run-AllTests
    }
} elseif ($TestMapping.ContainsKey($TestName)) {
    $sceneFile = $TestMapping[$TestName]
    $result = Run-SingleTest -SceneFile $sceneFile -Timeout $TimeoutSeconds
    
    if ($result) {
        Write-Host ""
        Write-Host "🎉 Test completed successfully!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host ""
        Write-Host "❌ Test failed or timed out" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "ERROR: Unknown test name '$TestName'" -ForegroundColor Red
    Show-Usage
    exit 1
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
