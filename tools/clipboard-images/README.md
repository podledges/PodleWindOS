# Current-clipboard image capture (on demand)

Windows owner of the issue 18 Stage 1 screenshot capture used by WezTerm Alt+V. This is **not** the clipboard autosaver. It runs only when explicitly invoked, reads the **current** Windows image clipboard, and publishes one unique PNG.

Live PodleShell autosaver (Screenshots2) and unmerged [PR 8](https://github.com/podledges/PodleWindOS/pull/8) stay untouched. This directory does not deploy, stop, or restart that listener.

## Exact call shape

Counterparts (`PodleTools/tools/clipboard-images/paste_capture.py`) must invoke Windows PowerShell 5.1 as:

```text
powershell.exe -NoProfile -STA -File <absolute-windows-path>\Capture-CurrentClipboardImage.ps1
powershell.exe -NoProfile -STA -File <absolute-windows-path>\Capture-CurrentClipboardImage.ps1 -DestinationDirectory <dir>
```

- `-STA` is required (WinForms clipboard).
- `-DestinationDirectory` is optional.
- Default destination: `%LOCALAPPDATA%\PodlePaste\staging`
- Do not pass `-Command`. Do not omit `-STA`.

## Success stdout

Exactly one JSON object, then a newline:

```json
{"schema":1,"kind":"image","label":"Screenshot Pasted","path":"C:\\Users\\ayden\\AppData\\Local\\PodlePaste\\staging\\paste-20250907T231501123Z-0123456789abcdef0123456789abcdef.png","sha256":"<64 lowercase hex of PNG bytes>"}
```

`path` is an absolute Windows path to a newly published unique PNG. `sha256` is SHA-256 of those PNG bytes.

## Failure

Nonzero exit. One stderr line. No success JSON. No success PNG. Error text never includes clipboard bytes or clipboard text.

Typical messages:

- `clipboard is not an image`
- `clipboard changed during capture`
- STA required (message includes the call shape above)

## Behavior

1. Record clipboard sequence number.
2. `ContainsImage`; if false, fail.
3. `GetImage` → PNG bytes.
4. Sequence number after the read must match the before value (bounded race check; no retry of a mismatched snapshot).
5. Write a unique `paste-<UTC>-<guid>.png` via temp + `File.Move` (atomic on the same volume). Never overwrite an earlier paste.
6. Print the success JSON.

No clipboard Set/Clear. No Screenshots2. No folder enumeration. No new port. No background listener.

## Staging retention

Published PNGs are kept. There is no automatic deletion, rotation, or cleanup framework. Review and remove staging files manually when appropriate. Unpublished `*.png.tmp` files are not success artifacts.

## Source-only

Do not copy this script over live Windows settings or auto-run it as part of merge. Deployment of the WezTerm bind is a separate, explicit step owned with PodleDoubleO.

## Synthetic tests

Tests use in-memory bitmaps and injected clipboard mocks. They never read, replace, or clear the user clipboard.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\clipboard-images\tests\Test-CaptureCurrentClipboardImage.ps1"
```

Ubuntu CI asserts the source contract from Python; it does not capture a clipboard.

## Ownership

- **This repo:** Windows STA capture + unique staging PNG + JSON.
- **PodleTools:** `paste_capture.py` runs this script, maps `path` to WSL, validates schema.
- **PodleDoubleO:** WezTerm Alt+V consumes the Tools CLI; does not reimplement capture.

PNG encode / SHA-256 / CreateNew write patterns follow the PR 8 / PodleShell listener style. The listener itself is not vendored here. See [`PROVENANCE.md`](PROVENANCE.md).
