#Requires -Version 5.1
<#
.SYNOPSIS
    Windows PodleMale TX: send PORT-NIXVM/1 HELLO to 127.0.0.1:46720.
.DESCRIPTION
    Loopback-only client. Expects PORT-NIXVM/1 ACK-HELLO from Nix Female.
    Prints ack-hello on success.
#>
[CmdletBinding()]
param(
    [string]$TxHost = '127.0.0.1',
    [int]$TxPort = 46720,
    [double]$TimeoutSec = 2
)

$ErrorActionPreference = 'Stop'
Import-Module -Force (Join-Path $PSScriptRoot '..\lib\PodleWindOS.psm1')

try {
    Send-PodleMaleHello -TxHost $TxHost -TxPort $TxPort -TimeoutSec $TimeoutSec
} catch {
    [Console]::Error.WriteLine("podlewindos: $($_.Exception.Message)")
    exit 1
}
