# DoECISORY - PowerShell Developer Reviser Mode
# Monitors the src/ directory and restarts Julia upon changes.

$HOST_URL = "http://127.0.0.1:8060"
$PROJECT_DIR = (Get-Item $PSScriptRoot).Parent.FullName
$SOURCE_DIR = Join-Path $PROJECT_DIR "src"
$APP_FILE = Join-Path $PROJECT_DIR "app.jl"

$env:DOECISORY_DEV = "true"
$env:DOECISORY_NO_BROWSER = "true"

$julia_proc = $null

function Write-Log {
    param(
        [string]$Source,
        [string]$Evt,
        [string]$Detail,
        [string]$Type = "INFO"
    )
    $ts = Get-Date -Format "HH:mm:ss.fff"
    
    $fg = "Blue"
    if ($Type -eq "OK") { $fg = "Green" }
    elseif ($Type -eq "WARN") { $fg = "Yellow" }
    elseif ($Type -eq "FAIL") { $fg = "Red" }
    elseif ($Type -eq "WAIT") { $fg = "Cyan" }

    Write-Host "[" -NoNewline -ForegroundColor Blue
    Write-Host "$ts" -NoNewline -ForegroundColor Blue
    Write-Host "] " -NoNewline -ForegroundColor Blue
    Write-Host "$($Source.PadRight(14))" -NoNewline -ForegroundColor Green
    Write-Host ": " -NoNewline
    Write-Host "$($Evt.PadRight(15)) " -NoNewline -ForegroundColor $fg
    Write-Host "$Detail" -ForegroundColor $fg
}

function Start-Julia {
    # Sysimage Detection Protocol: Use pre-compiled image if available.
    $SYSIMG_PATH = Join-Path $PROJECT_DIR "build\sysimage.dll"
    $SYSIMG_FLAG = ""
    if (Test-Path $SYSIMG_PATH) {
        $SYSIMG_FLAG = "--sysimage `"$SYSIMG_PATH`""
    }
    $script:julia_proc = Start-Process -FilePath "julia" `
        -ArgumentList "--depwarn=no $SYSIMG_FLAG --threads auto -O0 --project=`"$PROJECT_DIR`" `"$APP_FILE`"" `
        -RedirectStandardError "NUL" `
        -WorkingDirectory $PROJECT_DIR `
        -PassThru `
        -NoNewWindow
    return $script:julia_proc
}

function Get-SrcMtime {
    $files = Get-ChildItem -Path $SOURCE_DIR -Filter "*.jl" -Recurse
    $files += Get-Item -Path $APP_FILE
    return ($files | Measure-Object -Property LastWriteTime -Maximum).Maximum
}

$restart_count = 0
$uptime_seconds = 0
$last_mtime = Get-SrcMtime

try {
    Start-Process "http://127.0.0.1:8060"
} catch {}

try {
    $julia_proc = Start-Julia

    while ($true) {
        Start-Sleep -Seconds 1
        
        # Check if process is still alive
        if ($julia_proc.HasExited) {
            $restart_count++
            if ($restart_count -gt 3) {
                Write-Log -Source "DOECISORY" -Evt "BOOT_FAIL" -Detail "Exiting after 3 consecutive failures." -Type "FAIL"
                break
            }
            Write-Log -Source "DOECISORY" -Evt "RESTART" -Detail "Process terminated. Restarting ($restart_count/3)..." -Type "WARN"
            Start-Sleep -Seconds 2
            $julia_proc = Start-Julia
            $uptime_seconds = 0
            $last_mtime = Get-SrcMtime
            continue
        }

        # Julia is running; reset restart counter
        $uptime_seconds++
        if ($uptime_seconds -gt 15) {
            $restart_count = 0
        }

        $current_mtime = Get-SrcMtime
        if ($current_mtime -gt $last_mtime) {
            Write-Log -Source "RELOAD" -Evt "DETECTED" -Detail "Source change identified. Restarting server..." -Type "WARN"
            $last_mtime = $current_mtime

            # Stop Julia process
            try { Stop-Process -Id $julia_proc.Id -Force -ErrorAction SilentlyContinue } catch {}
            Start-Sleep -Seconds 1

            # Clear the port
            try {
                Get-NetTCPConnection -LocalPort 8060 -ErrorAction SilentlyContinue |
                Select-Object -ExpandProperty OwningProcess -ErrorAction SilentlyContinue |
                ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
            }
            catch {}

            Start-Sleep -Seconds 1
            $env:DOECISORY_NO_BROWSER = "true"
            $julia_proc = Start-Julia

            Write-Log -Source "RELOAD" -Evt "COMPLETE" -Detail "Server restarted. Refresh (F5) to see changes." -Type "OK"
        }
    }
}
finally {
    Write-Log -Source "SHUTDOWN" -Evt "WATCHER" -Detail "Cleaning up and exiting..." -Type "WARN"
    if ($julia_proc -and -not $julia_proc.HasExited) {
        try { Stop-Process -Id $julia_proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    }
}

