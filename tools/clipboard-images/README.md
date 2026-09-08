# Clipboard image autosave (Windows)

PodleWindOS is the canonical owner of this small, current-user Windows helper. It saves every newly copied clipboard image as a PNG in the configured destination. The established destination is:

- Windows: `C:\Users\ayden\Pictures\Screenshots2`
- NixOS/WSL: `/mnt/c/Users/ayden/Pictures/Screenshots2`

`DestinationPath` is a parameter on the listener and start script, so other users can select another folder.

The helper uses `WM_CLIPBOARDUPDATE` notifications and a WinForms message loop; it does not poll. It has no network access, listening port, upload, OCR, text logging, model call, or automatic image ingestion. It only reads image clipboard formats and never changes or clears the clipboard. Clipboard content present at startup is not replayed. Consecutive duplicate image content is hashed and skipped; a non-image update resets that deduplication boundary. Existing files are never overwritten, and timestamp collisions receive numeric suffixes.

## Ownership and counterpart

The optional NixOS/Pi counterpart is [`PodleTools/tools/clipboard-images`](https://github.com/podledges/PodleTools/tree/main/tools/clipboard-images). It only locates PNG files already saved in the shared folder; it does not run or manage this Windows listener.

The two tools do not depend on each other and create no dependency cycle. Their entire shared contract is saved PNG files in the agreed folder:

- **Required for the listener:** Windows, current-user access to the destination, Windows PowerShell 5.1, .NET Framework `System.Windows.Forms` and `System.Drawing`, and the Windows `user32.dll` clipboard-listener APIs.
- **Optional:** PodleTools on NixOS/Pi, only when another process needs to locate the saved files through the mounted path.

No Pi extension is required.

## Source-only migration status

This directory is source only. **Do not deploy it over, alongside, or in place of the currently running helper under `%LOCALAPPDATA%\PodleShell\ClipboardImageAutosave` yet.** Do not stop or restart that listener, and do not alter Windows startup or security settings as part of this migration.

The migrated listener deliberately retains the deployed named-mutex identity, `Local\PodleShell.ClipboardImageAutosave.<user SID>`. That shared identity prevents the old and future owner paths from running concurrently.

After this destination has landed, a separate, explicit future cutover can be performed:

1. Keep `C:\Users\ayden\Pictures\Screenshots2` as `DestinationPath` so consumers see the same PNG contract.
2. Use the **old deployed** `Stop-ClipboardImageAutosave.ps1` once and verify its listener stopped. Do not change autostart or security settings.
3. Copy this directory to `%LOCALAPPDATA%\PodleWindOS\ClipboardImageAutosave`.
4. Start the new copy explicitly with its `Start-ClipboardImageAutosave.ps1`. The retained mutex prevents overlap if the old listener was not actually stopped.
5. Validate one human-selected clipboard image and singleton behavior before removing old source files.

This is intentionally a manual cutover path, not an installer or automatic migration framework.

After PodleWindOS lands, PodleShell needs a follow-up cleanup: replace its duplicate `windows/clipboard-image-autosave/` implementation and README feature pointer with a deprecation/ownership pointer to this directory. That cleanup belongs to the PodleShell owner and is not performed here.

## Run (after an explicit cutover)

From the stable future location:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\PodleWindOS\ClipboardImageAutosave\Start-ClipboardImageAutosave.ps1"
```

For another destination:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\PodleWindOS\ClipboardImageAutosave\Start-ClipboardImageAutosave.ps1" -DestinationPath "D:\Pictures\Clipboard"
```

Stop it safely:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\PodleWindOS\ClipboardImageAutosave\Stop-ClipboardImageAutosave.ps1"
```

The helper uses the named mutex plus a verified PID file to prevent duplicate listeners and avoid stopping unrelated processes. Start/stop scripts print their result; normal listener operation is quiet. Failures are recorded in bounded logs at `%LOCALAPPDATA%\PodleWindOS\ClipboardImageAutosave\state\errors.log` and `errors.previous.log` (at most roughly 512 KiB combined).

No administrator access is needed. The helper deliberately does **not** create a scheduled task, registry entry, login persistence, service, or firewall rule.

## Synthetic test

The test creates generated in-memory bitmaps and temporary files. It never reads, replaces, or clears the user's clipboard and never opens existing screenshots.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\tools\clipboard-images\tests\Test-ClipboardImageAutosave.ps1"
```

## Privacy and disk use

Every newly copied image qualifies, regardless of whether it is a screenshot. This can save sensitive images, and disk usage grows without automatic cleanup. Files stay local and are never uploaded or automatically deleted; review and remove them manually when appropriate.

## Provenance and license

This implementation was migrated from the merged PodleShell implementation without redesigning its listener. See [`PROVENANCE.md`](PROVENANCE.md). This directory is distributed under the repository's MIT license; a copy is included as [`LICENSE`](LICENSE).
