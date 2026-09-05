# PodleMale — Windows TX hook

Windows-side transmitter toward Nix Female.

## Direction and endpoint

- Direction: Windows PodleMale TX → Nix PodleFemale RX.
- Destination: `127.0.0.1:46720`.
- Loopback only; non-loopback destinations are rejected.

## Handshake

Send with [`Send-PodleMale.ps1`](Send-PodleMale.ps1) from Windows PowerShell. Transmits `PORT-NIXVM/1 HELLO` and requires `PORT-NIXVM/1 ACK-HELLO`. Prints `ack-hello` on success.

The Nix-side Female listener is owned by `podledges/PodleTools`.

Captain runbook: [`../README.md`](../README.md).

## v1 diagnostics

Read-only WindOS-triggered diagnostics are a local path, not this handshake. See [`../lib/Invoke-WindOSDiagnostic.ps1`](../lib/Invoke-WindOSDiagnostic.ps1).

The communication graph remains postponed.
