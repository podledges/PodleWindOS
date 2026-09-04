# Windows-side Port NixVM v1 loopback duplex and read-only diagnostics.
# Handshake tokens: PORT-NIXVM/1 HELLO -> PORT-NIXVM/1 ACK-HELLO
# Female RX default: 127.0.0.1:42067
# Male TX default:   127.0.0.1:46720

Set-StrictMode -Version Latest

function Test-LoopbackHost {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName
    )
    if ($HostName -eq 'localhost') {
        return '127.0.0.1'
    }
    try {
        $ip = [System.Net.IPAddress]::Parse($HostName)
    } catch {
        throw 'host must be localhost or a numeric loopback address'
    }
    if (-not [System.Net.IPAddress]::IsLoopback($ip)) {
        throw 'host must be a loopback address'
    }
    return $HostName
}

function Receive-PortNixVMLine {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.Sockets.NetworkStream]$Stream,
        [int]$MaxBytes = 64
    )
    $bytes = New-Object System.Collections.Generic.List[byte]
    while ($bytes.Count -le $MaxBytes) {
        $value = $Stream.ReadByte()
        if ($value -lt 0) {
            break
        }
        [void]$bytes.Add([byte]$value)
        if ($value -eq 10) {
            return [System.Text.Encoding]::ASCII.GetString($bytes.ToArray())
        }
    }
    throw 'peer sent an incomplete or oversized message'
}

function Start-PodleFemaleListener {
    param(
        [string]$ListenHost = '127.0.0.1',
        [int]$ListenPort = 42067,
        [double]$TimeoutSec = 2,
        [switch]$Once
    )
    $ListenHost = Test-LoopbackHost -HostName $ListenHost
    $ip = [System.Net.IPAddress]::Parse($ListenHost)
    $listener = New-Object System.Net.Sockets.TcpListener $ip, $ListenPort
    $listener.Server.SetSocketOption(
        [System.Net.Sockets.SocketOptionLevel]::Socket,
        [System.Net.Sockets.SocketOptionName]::ReuseAddress,
        $true
    )
    $listener.Start()
    $actualPort = ([System.Net.IPEndPoint]$listener.LocalEndpoint).Port
    [Console]::Out.WriteLine("listening on ${ListenHost}:${actualPort}")
    [Console]::Out.Flush()
    $timeoutMs = [Math]::Max(1, [int]($TimeoutSec * 1000))
    try {
        while ($true) {
            $client = $listener.AcceptTcpClient()
            try {
                $stream = $client.GetStream()
                $stream.ReadTimeout = $timeoutMs
                $stream.WriteTimeout = $timeoutMs
                try {
                    $line = Receive-PortNixVMLine -Stream $stream
                } catch {
                    continue
                }
                if ($line -ne "PORT-NIXVM/1 HELLO`n") {
                    continue
                }
                $ack = [System.Text.Encoding]::ASCII.GetBytes("PORT-NIXVM/1 ACK-HELLO`n")
                $stream.Write($ack, 0, $ack.Length)
                $stream.Flush()
                [Console]::Out.WriteLine('hello')
                [Console]::Out.Flush()
            } finally {
                $client.Close()
            }
            if ($Once) {
                return
            }
        }
    } finally {
        $listener.Stop()
    }
}

function Send-PodleMaleHello {
    param(
        [string]$TxHost = '127.0.0.1',
        [int]$TxPort = 46720,
        [double]$TimeoutSec = 2
    )
    $TxHost = Test-LoopbackHost -HostName $TxHost
    $timeoutMs = [Math]::Max(1, [int]($TimeoutSec * 1000))
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $client.BeginConnect($TxHost, $TxPort, $null, $null)
        $signaled = $async.AsyncWaitHandle.WaitOne($timeoutMs, $false)
        if (-not $signaled) {
            throw "timeout connecting to ${TxHost}:${TxPort}"
        }
        $client.EndConnect($async)
        $stream = $client.GetStream()
        $stream.ReadTimeout = $timeoutMs
        $stream.WriteTimeout = $timeoutMs
        $hello = [System.Text.Encoding]::ASCII.GetBytes("PORT-NIXVM/1 HELLO`n")
        $stream.Write($hello, 0, $hello.Length)
        $stream.Flush()
        $line = Receive-PortNixVMLine -Stream $stream
        if ($line -ne "PORT-NIXVM/1 ACK-HELLO`n") {
            throw 'peer did not return PORT-NIXVM/1 ACK-HELLO'
        }
        [Console]::Out.WriteLine('ack-hello')
        [Console]::Out.Flush()
    } finally {
        $client.Close()
    }
}

function Invoke-ReadOnlyDiagnostic {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command
    )
    switch ($Command) {
        'computer-info' {
            Get-ComputerInfo | Out-String
        }
        'disk' {
            Get-PSDrive -PSProvider FileSystem |
                Select-Object Name, Used, Free |
                Format-List |
                Out-String
        }
        'process-list' {
            Get-Process |
                Select-Object Id, ProcessName, CPU, WorkingSet64 |
                Format-Table -AutoSize |
                Out-String
        }
        'adapters' {
            Get-NetAdapter |
                Select-Object Name, Status, MacAddress, LinkSpeed |
                Format-List |
                Out-String
        }
        'battery' {
            Get-CimInstance -ClassName Win32_Battery |
                Select-Object Name, EstimatedChargeRemaining, BatteryStatus |
                Format-List |
                Out-String
        }
        default {
            throw "command not allowed: $Command"
        }
    }
}

Export-ModuleMember -Function Test-LoopbackHost, Receive-PortNixVMLine, Start-PodleFemaleListener, Send-PodleMaleHello, Invoke-ReadOnlyDiagnostic
