# PodleFemale — Windows RX hook spec

Planning-only contract for the Windows-side receiver. This folder does not contain a working bridge, listener, PowerShell automation, or AutoHotkey script.

## Direction and endpoint

- Direction: Nix PodleMale TX → Windows PodleFemale RX.
- Listen endpoint: `127.0.0.1:42067` (Port NixVM).
- The Windows Female listener implementation is explicitly deferred.

## v1 permission intent

Accept only WindOS-triggered, read-only diagnostic intent, such as computer information, disks, process list, adapters, and battery. No elevation, registry writes, process kills, or installs.

Wire format, validation, and lifecycle remain unspecified until the communication graph is designed.
