# PodleMale — Windows TX hook spec

Planning-only contract for the Windows-side transmitter. This folder does not contain a working bridge, listener, PowerShell automation, or AutoHotkey script.

## Direction and endpoint

- Direction: Windows PodleMale TX → Nix PodleFemale RX.
- Destination: `127.0.0.1:67420`.
- The Nix-side Female listener is owned by `podledges/PodleTools`; implementation is out of scope here.

## v1 payload intent

Transmit requests/results for WindOS-triggered, read-only diagnostics only (for example computer information, disks, process list, adapters, and battery). No elevation, registry writes, kills, or installs.

Wire format, retry behavior, and lifecycle remain unspecified until the communication graph is designed.
