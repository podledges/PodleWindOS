# Provenance

`Capture-CurrentClipboardImage.ps1` is new on-demand capture for [PodleDoubleO issue 18](https://github.com/podledges/PodleDoubleO/issues/18). It is not a copy of the live autosaver and does not merge [PodleWindOS PR 8](https://github.com/podledges/PodleWindOS/pull/8).

PNG encoding, SHA-256, STA, `GetClipboardSequenceNumber`, and CreateNew/atomic write patterns follow:

- PodleWindOS PR 8 (`origin/fm/windos-clipboard-pair`, `tools/clipboard-images/ClipboardImageAutosave.Core.psm1`)
- which itself migrated from [PodleShell PR 2](https://github.com/podledges/PodleShell/pull/2) commit `e8413acbb279832879ce008385d900b90ce8738d`

Required pieces were reimplemented in `Capture-CurrentClipboardImage.Core.psm1` rather than importing the unmerged listener module. Listener files, mutex identity, Screenshots2 destination, and start/stop scripts are intentionally absent from this change.
