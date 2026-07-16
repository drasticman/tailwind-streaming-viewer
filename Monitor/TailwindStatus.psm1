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

Export-ModuleMember -Function Test-TcpPort
