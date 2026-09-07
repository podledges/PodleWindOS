# PodleWindOS

Windows/main-OS side of the localhost Port NixVM duplex. Female RX listens on `127.0.0.1:42067`. Male TX sends to `127.0.0.1:46720`. Binds are loopback-only.

v1 wire protocol is the handshake below. WindOS-triggered read-only diagnostics are a separate local path.

## Handshake

Client sends:

```text
PORT-NIXVM/1 HELLO
```

Listener replies:

```text
PORT-NIXVM/1 ACK-HELLO
```

Lines are ASCII and newline-terminated. Invalid, incomplete, and oversized messages are ignored. Receipt of a handshake is not authorization.

## Run it from Windows

Use Windows PowerShell 5.1 or PowerShell 7. From this repository:

```powershell
# Terminal 1 — Female RX (Port NixVM from Nix / WSL)
Set-Location path\to\PodleWindOS
powershell -NoProfile -ExecutionPolicy Bypass -File .\PodleFemale\Listen-PodleFemale.ps1
```

From WSL or Nix, send `PORT-NIXVM/1 HELLO` to `127.0.0.1:42067` (mirrored localhost or equivalent). The listener prints `hello` and replies `PORT-NIXVM/1 ACK-HELLO`.

```powershell
# Terminal 2 — Male TX toward Nix Female on 127.0.0.1:46720
powershell -NoProfile -ExecutionPolicy Bypass -File .\PodleMale\Send-PodleMale.ps1
```

Male TX prints `ack-hello` when Nix Female replies `PORT-NIXVM/1 ACK-HELLO`.

Non-loopback hosts are rejected:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PodleFemale\Listen-PodleFemale.ps1 -ListenHost 0.0.0.0
```

## Read-only diagnostics

Triggered locally on WindOS (`wind`, `windOS`, `main system` in sentence context). Not sent over the handshake.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\lib\Invoke-WindOSDiagnostic.ps1 computer-info
powershell -NoProfile -ExecutionPolicy Bypass -File .\lib\Invoke-WindOSDiagnostic.ps1 disk
powershell -NoProfile -ExecutionPolicy Bypass -File .\lib\Invoke-WindOSDiagnostic.ps1 process-list
powershell -NoProfile -ExecutionPolicy Bypass -File .\lib\Invoke-WindOSDiagnostic.ps1 adapters
powershell -NoProfile -ExecutionPolicy Bypass -File .\lib\Invoke-WindOSDiagnostic.ps1 battery
```

These cmdlets are allowlisted and run without elevation. Unknown names are refused.

## Python CLI (same handshake; used by tests)

```bash
bin/podlewindos listen --once          # Female RX, 127.0.0.1:42067
bin/podlewindos hello                  # Male TX, 127.0.0.1:46720
bin/podlewindos diag computer-info     # local diagnostics; requires Windows
```

`listen --host` and `hello --host` accept only loopback addresses.

## Clipboard image autosave

[`tools/clipboard-images/`](tools/clipboard-images/) is the canonical Windows owner of the event-driven clipboard-image listener. It works standalone and saves local PNG files without clipboard mutation, networking, overwrites, or startup replay. The optional [`PodleTools` counterpart](https://github.com/podledges/PodleTools/tree/main/tools/clipboard-images) only locates those files from NixOS/Pi.

The migration is source-only for now: do not change the currently deployed PodleShell listener. See the tool README for dependencies, synthetic tests, provenance, and the future explicit cutover procedure.

## Tests

```bash
python3 -m unittest discover -s tests -v
```

The clipboard-image helper has a separate Windows-only synthetic test documented in [`tools/clipboard-images/README.md`](tools/clipboard-images/README.md). It does not access the live clipboard.

## Layout

- [`PodleFemale/`](PodleFemale/) — Windows RX hook
- [`PodleMale/`](PodleMale/) — Windows TX hook
- [`WinSpec/`](WinSpec/) — Windows/main-OS facts loaded only for WindOS sentence context
- [`lib/PodleWindOS.psm1`](lib/PodleWindOS.psm1) — PowerShell handshake and diagnostic implementations
- [`src/podlewindos/`](src/podlewindos/) — portable handshake engine
- [`tools/clipboard-images/`](tools/clipboard-images/) — standalone Windows clipboard-image PNG saver

The communication graph is postponed.
