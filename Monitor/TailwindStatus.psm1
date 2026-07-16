# Shared read-only status helpers for the Tailwind Streaming Viewer.

function Test-TcpPort {
    param(
        [string]$ComputerName = '127.0.0.1',
        [int]$Port,
        [int]$TimeoutMs = 500
    )

    $client = New-Object System.Net.Sockets.TcpClient

    try {
        $result = $client.BeginConnect(
            $ComputerName,
            $Port,
            $null,
            $null
        )

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

    return @(
        $items | Where-Object {
            $_.CommandLine -match $CommandLinePattern
        }
    ).Count -gt 0
}

Export-ModuleMember -Function Test-TcpPort, Get-ProcessMatch