# VM and network facts

- Nix tools location: `podledges/PodleTools`
- Port NixVM (Nix TX → Windows RX): `127.0.0.1:42067`
- Return (Windows TX → Nix RX): `127.0.0.1:46720`
- Duplex model: crossed Male/Female channels.
- Handshake: `PORT-NIXVM/1 HELLO` / `PORT-NIXVM/1 ACK-HELLO`, loopback only.
- Communication graph: postponed.
