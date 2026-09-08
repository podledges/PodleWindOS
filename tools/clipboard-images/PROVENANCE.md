# Provenance

## Clipboard image autosave

The clipboard image autosave implementation and synthetic test in this directory were copied from PodleShell and adapted for canonical ownership by PodleWindOS.

- Source repository: <https://github.com/podledges/PodleShell>
- Merged pull request: <https://github.com/podledges/PodleShell/pull/2>
- Source commit: [`e8413acbb279832879ce008385d900b90ce8738d`](https://github.com/podledges/PodleShell/commit/e8413acbb279832879ce008385d900b90ce8738d)
- Original author: Ayden / podles
- Migrated files: `ClipboardImageAutosave.Core.psm1`, `ClipboardImageAutosave.ps1`, `Start-ClipboardImageAutosave.ps1`, `Stop-ClipboardImageAutosave.ps1`, and `tests/Test-ClipboardImageAutosave.ps1`
- Landed on PodleWindOS main via [PR 8](https://github.com/podledges/PodleWindOS/pull/8)

Ownership labels and future state paths were changed from PodleShell to PodleWindOS. The deployed mutex name remains unchanged intentionally, so the old and new owner paths cannot run simultaneously during a future explicit cutover. Core event-listener, image encoding, deduplication, collision-safe writing, bounded retry, error logging, and safe-stop behavior are otherwise preserved.

The source repository did not contain a repository-level license file at migration time. PodleWindOS distributes this migrated implementation under its MIT license; see [`LICENSE`](LICENSE) and the repository root [`LICENSE`](../../LICENSE).

## On-demand current-clipboard capture

`Capture-CurrentClipboardImage.ps1` is new on-demand capture for [PodleDoubleO issue 18](https://github.com/podledges/PodleDoubleO/issues/18). It is not a copy of the live autosaver and does not replace the in-tree listener.

PNG encoding, SHA-256, STA, `GetClipboardSequenceNumber`, and CreateNew/atomic write patterns follow `ClipboardImageAutosave.Core.psm1` (PR 8 / PodleShell PR 2). Required pieces were reimplemented in `Capture-CurrentClipboardImage.Core.psm1` rather than importing the listener module, so paste staging stays independent of Screenshots2, the mutex, and start/stop scripts.
