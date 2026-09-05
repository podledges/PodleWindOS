# Windows/main OS facts

- Host role: Windows main OS (WindOS).
- v1 actions: WindOS-triggered read-only diagnostics only (`computer-info`, `disk`, `process-list`, `adapters`, `battery`).
- Diagnostic entry point: [`../lib/Invoke-WindOSDiagnostic.ps1`](../lib/Invoke-WindOSDiagnostic.ps1).
- No elevation, registry writes, process kills, or installs in v1.
