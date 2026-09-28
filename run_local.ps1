param(
    [switch]$Reseed
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -LiteralPath $projectRoot

try {
    $python = (Get-Command python -ErrorAction Stop).Source
    & $python -c "import fastapi, uvicorn"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Installing the app's Python requirements..."
        & $python -m pip install -r requirements.txt
        if ($LASTEXITCODE -ne 0) {
            throw "Dependency installation failed. See the pip error above and retry."
        }
    }

    $needsSeed = $Reseed -or -not (Test-Path -LiteralPath (Join-Path $projectRoot "ev_charging.db"))
    if (-not $needsSeed) {
        & $python -c "from app.database import get_connection; c=get_connection(); valid=c.execute('SELECT COUNT(*) FROM stations').fetchone()[0] >= 18 and c.execute('SELECT COUNT(*) FROM users').fetchone()[0] >= 4 and c.execute('SELECT COUNT(*) FROM vehicles').fetchone()[0] >= 4; c.close(); raise SystemExit(0 if valid else 1)" 2>$null
        $needsSeed = $LASTEXITCODE -ne 0
    }

    if ($needsSeed) {
        Write-Host "Seeding the demo charging stations..."
        & $python (Join-Path $projectRoot "seed.py")
        if ($LASTEXITCODE -ne 0) {
            throw "Database seeding failed. See the seed error above and retry."
        }
    }

    $api = Get-NetTCPConnection -State Listen -LocalPort 8000 -ErrorAction SilentlyContinue |
        Select-Object -First 1
    $frontend = Get-NetTCPConnection -State Listen -LocalPort 5500 -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if ($api) {
        try {
            $health = Invoke-RestMethod -Uri "http://127.0.0.1:8000/" -TimeoutSec 3
            if ($health.status -ne "ok") {
                throw "Port 8000 is occupied by a different service. Stop it and rerun run_local.bat."
            }
            Write-Host "Using the existing EV charging API on port 8000."
        } catch {
            if ($_.Exception.Message -like "Port 8000 is occupied*") {
                throw
            }
            throw "Port 8000 is already in use, but it is not responding as the EV API. Stop the other process and rerun run_local.bat."
        }
    } else {
        $apiProcess = Start-Process -FilePath $python `
            -ArgumentList @("-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000") `
            -WorkingDirectory $projectRoot -PassThru -WindowStyle Minimized

        $apiReady = $false
        for ($attempt = 0; $attempt -lt 40; $attempt++) {
            Start-Sleep -Milliseconds 500
            if ($apiProcess.HasExited) {
                throw "The EV API stopped during startup. Run 'python -m uvicorn app.main:app --host 0.0.0.0 --port 8000' in a terminal to inspect the error."
            }
            try {
                $health = Invoke-RestMethod -Uri "http://127.0.0.1:8000/" -TimeoutSec 2
                if ($health.status -eq "ok") {
                    $apiReady = $true
                    break
                }
            } catch {
                # Keep waiting while Uvicorn starts; report a useful error after the timeout.
            }
        }
        if (-not $apiReady) {
            throw "The EV API did not become ready on port 8000. Check that this port is available."
        }
        Write-Host "EV charging API is running on port 8000."
    }

    if ($frontend) {
        try {
            $null = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:5500/mobile.html" -TimeoutSec 3
            Write-Host "Using the existing frontend server on port 5500."
        } catch {
            throw "Port 5500 is in use, but it is not serving this app. Stop the other process or use VS Code Live Server."
        }
    } else {
        $frontendDirectory = Join-Path $projectRoot "frontend"
        $frontendProcess = Start-Process -FilePath $python `
            -ArgumentList "-m http.server 5500 --bind 0.0.0.0 --directory `"$frontendDirectory`"" `
            -WorkingDirectory $projectRoot -PassThru -WindowStyle Minimized

        $frontendReady = $false
        for ($attempt = 0; $attempt -lt 20; $attempt++) {
            Start-Sleep -Milliseconds 250
            if ($frontendProcess.HasExited) {
                throw "The frontend server stopped during startup. Check that port 5500 is available."
            }
            try {
                $null = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:5500/mobile.html" -TimeoutSec 2
                $frontendReady = $true
                break
            } catch {
                # Keep waiting while the static server starts; report a useful error after the timeout.
            }
        }
        if (-not $frontendReady) {
            throw "The mobile page did not become available on port 5500. Check that this port is available."
        }
    }

    $localUrl = "http://127.0.0.1:5500/mobile.html"
    Write-Host ""
    Write-Host "Voltway is ready: $localUrl"
    Write-Host "The API address is detected from this computer automatically."

    $lanAddresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" }
    foreach ($address in $lanAddresses) {
        Write-Host "On this Wi-Fi network: http://$($address.IPAddress):5500/mobile.html"
    }

    Start-Process $localUrl
    Write-Host ""
    Write-Host "Keep the minimized API and frontend windows open while using Voltway."
} catch {
    Write-Host ""
    Write-Host "Voltway could not start: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
