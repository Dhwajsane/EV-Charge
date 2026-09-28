$ErrorActionPreference = "Stop"
$servers = @(
    @{
        Port = 8000
        Pattern = "uvicorn app.main:app --host 0.0.0.0 --port 8000"
    },
    @{
        Port = 5500
        Pattern = "http.server 5500 --bind 0.0.0.0"
    }
)

foreach ($server in $servers) {
    $listener = Get-NetTCPConnection -State Listen -LocalPort $server.Port -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $listener) {
        Write-Host "No Voltway server is listening on port $($server.Port)."
        continue
    }

    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $($listener.OwningProcess)" -ErrorAction SilentlyContinue
    if ($process -and $process.CommandLine -like "*$($server.Pattern)*") {
        Stop-Process -Id $process.ProcessId
        Write-Host "Stopped Voltway's server on port $($server.Port)."
    } else {
        Write-Host "Port $($server.Port) belongs to another app; leaving it untouched." -ForegroundColor Yellow
    }
}
