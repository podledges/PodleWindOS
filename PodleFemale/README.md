# PodleFemale — Windows RX hook

Windows-side receiver for Port NixVM.

## Direction and endpoint

- Direction: Nix PodleMale TX → Windows PodleFemale RX.
- Listen endpoint: `127.0.0.1:42067` (Port NixVM).
- Loopback only; non-loopback binds are rejected.

## Handshake

Listen with [`Listen-PodleFemale.ps1`](Listen-PodleFemale.ps1) from Windows PowerShell. On `PORT-NIXVM/1 HELLO`, reply `PORT-NIXVM/1 ACK-HELLO` and print `hello`.

Captain runbook: [`../README.md`](../README.md).

## v1 diagnostics

Read-only WindOS-triggered diagnostics are a local path, not this handshake. See [`../lib/Invoke-WindOSDiagnostic.ps1`](../lib/Invoke-WindOSDiagnostic.ps1).

The communication graph remains postponed.
