#Requires -Version 5.1
<#
.SYNOPSIS
    Windows PodleFemale RX: listen on 127.0.0.1:42067 for PORT-NIXVM/1 HELLO.
.DESCRIPTION
    Loopback-only listener. Replies PORT-NIXVM/1 ACK-HELLO. Invalid, incomplete,
    and oversized messages are ignored. This handshake is not authorization.
#>
[CmdletBinding()]
param(
    [string]$ListenHost = '127.0.0.1',
    [int]$ListenPort = 42067,
    [double]$TimeoutSec = 2,
    [switch]$Once
)

$ErrorActionPreference = 'Stop'
Import-Module -Force (Join-Path $PSScriptRoot '..\lib\PodleWindOS.psm1')

try {
    Start-PodleFemaleListener -ListenHost $ListenHost -ListenPort $ListenPort -TimeoutSec $TimeoutSec -Once:$Once
} catch {
    [Console]::Error.WriteLine("podlewindos: $($_.Exception.Message)")
    exit 1
}
