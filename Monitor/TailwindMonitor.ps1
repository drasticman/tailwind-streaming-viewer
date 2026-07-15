# Tailwind Streaming Server Monitor v0.3.1
# Launches the streaming stack, then provides a status dashboard.
# This version does not stop, restart, or automatically recover services.

$ErrorActionPreference = 'SilentlyContinue'

$StreamRoot = 'C:\Streaming'
$MediaMtxApi = 'http://127.0.0.1:9997/v3/paths/list'
$RefreshSeconds = 2


$MediaMtxDir = 'C:\Apps\MediaMTX'
$CaddyDir = Join-Path $StreamRoot 'Caddy'
$AuthDir = Join-Path $StreamRoot 'Auth'


Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class TailwindWindowControl
{
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
}
'@

$ServiceWindows = @{
    D1 = 'MediaMTX'
    D2 = 'Caddy'
    D3 = 'Auth Server'
    D4 = 'FFmpeg MultiAudio Clean'
}

function Get-ServiceWindow {
    param([string]$WindowTitle)

    Get-Process |
        Where-Object {
            $_.MainWindowHandle -ne 0 -and
            $_.MainWindowTitle.StartsWith($WindowTitle, [System.StringComparison]::OrdinalIgnoreCase)
        } |
        Select-Object -First 1
}

function Toggle-ServiceWindow {
    param([string]$WindowTitle)

    $process = Get-ServiceWindow -WindowTitle $WindowTitle
    if (-not $process) {
        return $false
    }

    $handle = $process.MainWindowHandle

    if ([TailwindWindowControl]::IsIconic($handle)) {
        [void][TailwindWindowControl]::ShowWindowAsync($handle, 9)
        [void][TailwindWindowControl]::SetForegroundWindow($handle)
    }
    else {
        [void][TailwindWindowControl]::ShowWindowAsync($handle, 2)
    }

    return $true
}

function Start-ConsoleService {
    param(
        [string]$WindowTitle,
        [string]$WorkingDirectory,
        [string]$Command
    )

    $cmdLine = "title $WindowTitle && cd /d `"$WorkingDirectory`" && $Command"

    return Start-Process `
        -FilePath 'cmd.exe' `
        -ArgumentList @('/k', $cmdLine) `
        -WindowStyle Minimized `
        -PassThru
}

function Start-StreamingServices {
    $launched = @{}

    if (-not (Get-ProcessMatch -Name 'mediamtx.exe')) {
        $launched.MediaMTX = Start-ConsoleService `
            -WindowTitle 'MediaMTX' `
            -WorkingDirectory $MediaMtxDir `
            -Command 'mediamtx.exe'
    }

    if (-not (Get-ProcessMatch -Name 'caddy.exe')) {
        $launched.Caddy = Start-ConsoleService `
            -WindowTitle 'Caddy' `
            -WorkingDirectory $CaddyDir `
            -Command 'caddy run --config Caddyfile'
    }

    if (-not (Get-ProcessMatch -Name 'python.exe' -CommandLinePattern 'auth_server\.py')) {
        $authLauncher = Join-Path $AuthDir 'RestartAuthServer.bat'
        Start-Process `
            -FilePath 'cmd.exe' `
            -ArgumentList @('/c', "call `"$authLauncher`"") `
            -WindowStyle Hidden `
            -Wait
    }

    $ffmpegRunning = Get-ProcessMatch `
        -Name 'ffmpeg.exe' `
        -CommandLinePattern 'MultiAudio(_clean)?'

    $multiAudioWindow = Get-CimInstance Win32_Process -Filter "Name='cmd.exe'" |
        Where-Object { $_.CommandLine -match 'clean_multiaudio\.bat' }

    if (-not $ffmpegRunning -and @($multiAudioWindow).Count -eq 0) {
        $launched.MultiAudio = Start-ConsoleService `
            -WindowTitle 'FFmpeg MultiAudio Clean' `
            -WorkingDirectory $StreamRoot `
            -Command 'call clean_multiaudio.bat'
    }

    return $launched
}

function Test-TcpPort {
    param(
        [string]$ComputerName = '127.0.0.1',
        [int]$Port,
        [int]$TimeoutMs = 500
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $result = $client.BeginConnect($ComputerName, $Port, $null, $null)
        if (-not $result.AsyncWaitHandle.WaitOne($TimeoutMs, $false)) {
            return $false
        }
        $client.EndConnect($result)
        return $true
    }
    catch {
        return $false
    }
    finally {
        $client.Close()
    }
}

function Get-ProcessMatch {
    param(
        [string]$Name,
        [string]$CommandLinePattern = ''
    )

    $items = Get-CimInstance Win32_Process -Filter "Name='$Name'"
    if ([string]::IsNullOrWhiteSpace($CommandLinePattern)) {
        return @($items).Count -gt 0
    }

    return @($items | Where-Object { $_.CommandLine -match $CommandLinePattern }).Count -gt 0
}

function Get-ProjectMetadata {
    $result = @{
        MainProject = $null
        StreamLabels = @{}
    }

    $projectsDir = Join-Path $StreamRoot 'Web\projects'
    $mainPath = Join-Path $projectsDir 'main.json'

    if (Test-Path $mainPath) {
        try {
            $main = Get-Content $mainPath -Raw | ConvertFrom-Json
            $result.MainProject = [string]$main.mainProject
        }
        catch { }
    }

    if (Test-Path $projectsDir) {
        Get-ChildItem $projectsDir -Filter '*.json' | Where-Object { $_.Name -ne 'main.json' } | ForEach-Object {
            try {
                $project = Get-Content $_.FullName -Raw | ConvertFrom-Json
                $slug = $_.BaseName
                $projectName = if ($project.name) { [string]$project.name } else { $slug }

                if ($project.streams) {
                    foreach ($property in $project.streams.PSObject.Properties) {
                        $path = [string]$property.Value
                        if (-not [string]::IsNullOrWhiteSpace($path)) {
                            $result.StreamLabels[$path] = "$projectName $($property.Name) Cam"
                        }
                    }
                }

                if ($project.audioStream) {
                    $result.StreamLabels[[string]$project.audioStream] = "$projectName Remote Audio"
                }
            }
            catch { }
        }
    }

    return $result
}

function Write-State {
    param(
        [string]$Label,
        [bool]$Healthy,
        [string]$Detail
    )

    Write-Host ('{0,-17}' -f $Label) -NoNewline
    if ($Healthy) {
        Write-Host '[OK] ' -ForegroundColor Green -NoNewline
    }
    else {
        Write-Host '[!!] ' -ForegroundColor Red -NoNewline
    }
    Write-Host $Detail
}

function Write-StreamState {
    param(
        [string]$Label,
        [bool]$Online,
        [int]$Readers,
        [string]$PathName
    )

    Write-Host ('{0,-28}' -f $Label) -NoNewline
    if ($Online) {
        Write-Host 'LIVE    ' -ForegroundColor Green -NoNewline
        Write-Host ("{0} direct reader(s)   [{1}]" -f $Readers, $PathName)
    }
    else {
        Write-Host 'OFFLINE ' -ForegroundColor DarkGray -NoNewline
        Write-Host ("[{0}]" -f $PathName) -ForegroundColor DarkGray
    }
}

function Get-DashboardData {
    $data = @{
        MediaMtxProcess = Get-ProcessMatch -Name 'mediamtx.exe'
        AuthProcess = Get-ProcessMatch -Name 'python.exe' -CommandLinePattern 'auth_server\.py'
        CaddyProcess = Get-ProcessMatch -Name 'caddy.exe'
        FfmpegProcess = Get-ProcessMatch -Name 'ffmpeg.exe' -CommandLinePattern 'MultiAudio(_clean)?'
        MediaMtxApiOk = $false
        AuthPortOk = Test-TcpPort -Port 8081
        CaddyPortOk = Test-TcpPort -Port 443
        WebRtcUdpListening = $false
        WebRtcTcpListening = Test-TcpPort -Port 8189
        Paths = @()
        ApiError = $null
    }

    try {
        $response = Invoke-RestMethod -Uri $MediaMtxApi -TimeoutSec 1
        $data.MediaMtxApiOk = $true
        $data.Paths = @($response.items)
    }
    catch {
        $data.ApiError = $_.Exception.Message
    }

    # UDP cannot be tested with a TCP connection. Confirm that Windows has a UDP listener.
    try {
        $udp = Get-NetUDPEndpoint -LocalPort 8189
        $data.WebRtcUdpListening = @($udp).Count -gt 0
    }
    catch { }

    return $data
}

$launchedProcesses = Start-StreamingServices
Start-Sleep -Milliseconds 750

$projectMetadata = Get-ProjectMetadata
$forceRefresh = $true

while ($true) {
    if ($forceRefresh) {
        $forceRefresh = $false
    }

    $dashboard = Get-DashboardData

    Clear-Host
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '              TAILWIND STREAMING SERVER' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''

    Write-Host 'SERVICES' -ForegroundColor White
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-State 'MediaMTX' ($dashboard.MediaMtxProcess -and $dashboard.MediaMtxApiOk) $(if ($dashboard.MediaMtxApiOk) { 'Process running; API :9997 responding' } elseif ($dashboard.MediaMtxProcess) { 'Process running; API not responding' } else { 'Process not detected' })
    Write-State 'Auth Server' ($dashboard.AuthProcess -and $dashboard.AuthPortOk) $(if ($dashboard.AuthPortOk) { 'Process running; HTTP :8081 responding' } elseif ($dashboard.AuthProcess) { 'Process running; port not responding' } else { 'Process not detected' })
    Write-State 'Caddy' ($dashboard.CaddyProcess -and $dashboard.CaddyPortOk) $(if ($dashboard.CaddyPortOk) { 'Process running; HTTPS :443 listening' } elseif ($dashboard.CaddyProcess) { 'Process running; HTTPS not listening' } else { 'Process not detected' })
    Write-State 'MultiAudio FFmpeg' $dashboard.FfmpegProcess $(if ($dashboard.FfmpegProcess) { 'Running / waiting for source' } else { 'Not running' })
    Write-State 'WebRTC UDP' $dashboard.WebRtcUdpListening $(if ($dashboard.WebRtcUdpListening) { ':8189 listening' } else { ':8189 not detected' })
    Write-State 'WebRTC TCP' $dashboard.WebRtcTcpListening $(if ($dashboard.WebRtcTcpListening) { ':8189 listening' } else { ':8189 not detected' })

    Write-Host ''
    Write-Host 'PROJECT' -ForegroundColor White
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    if ([string]::IsNullOrWhiteSpace($projectMetadata.MainProject)) {
        Write-Host 'Main project: legacy/default configuration' -ForegroundColor Yellow
    }
    elseif ($projectMetadata.MainProject -eq 'offline') {
        Write-Host 'Main project: OFFLINE / public landing page' -ForegroundColor Yellow
    }
    else {
        Write-Host ("Main project: {0}" -f $projectMetadata.MainProject) -ForegroundColor Cyan
    }

    Write-Host ''
    Write-Host 'ACTIVE STREAMS' -ForegroundColor White
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray

    if (-not $dashboard.MediaMtxApiOk) {
        Write-Host 'MediaMTX API unavailable; stream status cannot be read.' -ForegroundColor Red
    }
    elseif (@($dashboard.Paths).Count -eq 0) {
        Write-Host 'No paths are currently active.' -ForegroundColor DarkGray
    }
    else {
        foreach ($path in ($dashboard.Paths | Sort-Object name)) {
            $name = [string]$path.name
            $label = if ($projectMetadata.StreamLabels.ContainsKey($name)) {
                $projectMetadata.StreamLabels[$name]
            }
            else {
                $name
            }

            $directReaders = @($path.readers | Where-Object { $_.type -ne 'hlsMuxer' }).Count
            Write-StreamState -Label $label -Online ([bool]$path.ready -and [bool]$path.available) -Readers $directReaders -PathName $name
        }
    }

    Write-Host ''
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host ("Last refresh: {0}    Refresh: {1}s" -f (Get-Date -Format 'yyyy-MM-dd hh:mm:ss tt'), $RefreshSeconds)
    Write-Host '1-4 = toggle consoles    R = refresh now    Q = close monitor' -ForegroundColor DarkGray

    $deadline = (Get-Date).AddSeconds($RefreshSeconds)
    while ((Get-Date) -lt $deadline) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true).Key
            if ($key -eq [ConsoleKey]::Q) {
                return
            }
            if ($key -eq [ConsoleKey]::R) {
                $forceRefresh = $true
                break
            }

            $keyName = $key.ToString()
            if ($ServiceWindows.ContainsKey($keyName)) {
                [void](Toggle-ServiceWindow -WindowTitle $ServiceWindows[$keyName])
                $forceRefresh = $true
                break
            }
        }
        Start-Sleep -Milliseconds 100
    }
}
