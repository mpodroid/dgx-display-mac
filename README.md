# dgx-display-mac

Menu-bar face for the head Spark. It does not replace `dgx-display` and it does not talk to the worker.

The app keeps one SSH session to the head and reads the feed the panel service publishes:

```
/usr/bin/dgx-display-writer --follow
```

The service is the only collector. It writes each `SS1` line to `/run/dgx-display/feed`, then to the panel. `--follow` copies that socket to stdout and does not sample. Five seconds without a line is WEDGE. A dropped session reconnects on its own.

SERVE and STALL use a colored icon for the state. The rates beside it use the menu bar's own text color: decode, then prefill, or the disk IO request rate. Other faces stay a colored word. A rate that has faded is `--`.

Defaults are user `admin`, host `spark-b1fa.local`, and the NVIDIA Sync key at `~/Library/Application Support/NVIDIA/Sync/config/nvsync.key`. Right-click the menu bar item for Settings and Quit. Settings edits the host (an IP or a hostname), the user, and the key path. They are remembered. The key is not embedded.

Build and wrap the menu-bar app (no dock icon):

```
scripts/build-app.sh
open "DGX Display.app"
```

The build runs the fixture test, which parses an `SS1` line without SSH. The bundle is signed so macOS can remember Local Network access. The first launch asks for that access. Until it is allowed, SSH fails with "No route to host" even though the same command works in Terminal.
