# Mock Service

A home-manager module (`modules/home-manager/mock-service.nix`) that demonstrates running a
user systemd service on COSMIC Atomic (Fedora Atomic + COSMIC DE) with a system tray icon
that shows service status and provides start/stop controls.

## How it works

### Components

**`mock-service.service`**
A simple looping shell script that writes a timestamped heartbeat to the systemd journal
every 10 seconds via `systemd-cat`. Not started automatically — controlled entirely by the
tray icon.

**`mock-service-tray.service`**
A Python process that registers a
[StatusNotifierItem](https://www.freedesktop.org/wiki/Specifications/StatusNotifierItem/)
on the session D-Bus. Starts automatically via `WantedBy=tray.target` when the COSMIC
session starts. Provides:
- A green circle icon when `mock-service` is active, grey when inactive
- Immediate "starting..." / "stopping..." label feedback when actions are triggered
- A right-click menu with Start, Stop, and Quit items
- Polls service state every 3 seconds and updates the icon accordingly
- Stopping the service when Quit is clicked before exiting

**`mock-service-tray` binary**
A Python script bundled as a Nix derivation using `dbus-python` and `pygobject3`. Lives in
`~/.nix-profile/bin/` inside the `nix-43` toolbox container.

**`mock-service-tray.desktop`**
An XDG desktop entry that lets the COSMIC app launcher manually start the tray service via
`systemctl --user start --no-block mock-service-tray.service`.

### Execution flow

```
COSMIC session starts
  -> tray.target activates
  -> mock-service-tray.service starts
  -> toolbox --container nix-43 run mock-service-tray
  -> Python registers org.kde.StatusNotifierItem-mock-service on D-Bus
  -> RegisterStatusNotifierItem with com.system76.CosmicStatusNotifierWatcher
  -> COSMIC panel shows tray icon

User clicks Start
  -> COSMIC sends com.canonical.dbusmenu Event(id=3, "clicked")
  -> _starting = True, LayoutUpdated + NewIcon sent immediately
  -> menu label shows "starting..." instantly
  -> run_systemctl("start", ...) dispatched on background thread
  -> poll loop detects active within 3s
  -> GLib.idle_add schedules do_update on main thread
  -> _starting cleared, NewIcon + LayoutUpdated sent
  -> icon turns green

User clicks Stop
  -> _stopping = True, LayoutUpdated + NewIcon sent immediately
  -> menu label shows "stopping..." instantly
  -> run_systemctl("stop", ...) dispatched on background thread
  -> poll loop detects inactive within 3s
  -> _stopping cleared, icon turns grey

User clicks Quit (service active)
  -> _quitting = True, _stopping = True, signals sent immediately
  -> run_systemctl("stop", ...) dispatched on background thread (fire and forget)
  -> poll loop detects inactive via do_update
  -> do_update sees _quitting + not active: calls loop.quit() on main thread
  -> exits immediately once service is inactive

User clicks Quit (service inactive)
  -> _quitting = True, service already inactive
  -> stop_event.set() + GLib.idle_add(loop.quit) called immediately
  -> exits instantly
```

### Why toolbox run is used for ExecStart

Home-manager runs inside the `nix-43` toolbox container, but systemd runs on the host.
The `duplicateSystemdUnits` activation hook copies unit files to `~/.config/systemd/user/`
as plain files (not symlinks) so the host systemd can read them. However, Nix store paths
(`/nix/store/...`) in `ExecStart` don't exist on the host filesystem — only inside the
container.

The solution is `toolbox --container nix-43 run <binary-name>`, which executes the binary
by name from the container's PATH (`~/.nix-profile/bin/`). This is the same pattern used
by `tailscale-systray.service`.

### Why ExecStart cannot use pkgs.writeShellScript directly

`pkgs.writeShellScript` produces a Nix store path. That path is interpolated into the unit
file at build time. The unit file is then copied to the host by `duplicateSystemdUnits`, but
the store path it references doesn't exist on the host — only inside the container. The fix
is to use `pkgs.writeShellScriptBin` to install the script into `~/.nix-profile/bin/` and
reference it by name via `toolbox run`.

## Key lessons

### COSMIC StatusNotifierWatcher

COSMIC uses `com.system76.CosmicStatusNotifierWatcher` as the D-Bus bus name, but implements
the standard `org.kde.StatusNotifierWatcher` interface. Registration must use the COSMIC bus
name with the KDE interface name:

```python
watcher = bus.get_object(
    "com.system76.CosmicStatusNotifierWatcher",
    "/StatusNotifierWatcher",
)
watcher.RegisterStatusNotifierItem(
    "/StatusNotifierItem",
    dbus_interface="org.kde.StatusNotifierWatcher",
)
```

### dbus-python signals must be emitted on the GLib main loop thread

`dbus-python` is not thread-safe. Emitting signals (`NewIcon`, `LayoutUpdated`, etc.) from
a background thread is silently dropped. Use `GLib.idle_add` to schedule signal emission
back onto the main loop thread:

```python
def do_update(icon):
    ...
    icon.NewIcon()
    return False  # do not reschedule

# from background thread:
GLib.idle_add(do_update, icon)
```

### GLib.MainLoop.is_running() returns False from background threads

`loop.is_running()` only returns `True` from the thread that called `loop.run()`. Use a
`threading.Event` as the stop condition for background threads instead:

```python
stop_event = threading.Event()
threading.Thread(target=poll_loop, args=(icon, stop_event), daemon=True).start()
loop.run()
```

### Use stop_event.wait() instead of time.sleep() in the poll loop

`stop_event.wait(POLL_INTERVAL)` blocks for up to `POLL_INTERVAL` seconds but returns
immediately when the event is set. This means the poll thread wakes up instantly on shutdown
rather than waiting out the full sleep interval:

```python
def poll_loop(icon, stop_event):
    while not stop_event.wait(POLL_INTERVAL):
        GLib.idle_add(do_update, icon)
```

### Don't block the main loop thread on subprocess calls

`run_systemctl` uses `subprocess.run` which blocks until the process exits. Calling it
directly in a D-Bus method handler (which runs on the GLib main loop thread) prevents signals
like `LayoutUpdated` and `NewIcon` from being dispatched until after the call returns — so
any immediate UI feedback appears only after the action completes, not before.

The fix is to dispatch the subprocess call on a background thread and emit signals
immediately on the main thread:

```python
# Wrong: blocks main loop, signals are delayed
def Event(self, item_id, event_id, data, timestamp):
    self._stopping = True
    self.LayoutUpdated(...)  # not dispatched until run_systemctl returns
    run_systemctl("stop", SERVICE_NAME)

# Correct: signals dispatched immediately, stop runs in background
def Event(self, item_id, event_id, data, timestamp):
    self._stopping = True
    self.LayoutUpdated(...)  # dispatched immediately
    threading.Thread(target=run_systemctl, args=("stop", SERVICE_NAME), daemon=True).start()
```

### Decouple quit from subprocess completion

Calling `loop.quit()` after `run_systemctl("stop", ...)` in a background thread means the
tray waits for systemd to fully confirm the stop before exiting — which can take several
seconds. Instead, fire the stop as a background thread and let the poll loop detect the
inactive state and trigger quit via `do_update`:

```python
# In Event handler (Quit clicked, service active):
self._quitting = True
threading.Thread(target=run_systemctl, args=("stop", SERVICE_NAME), daemon=True).start()

# In do_update (runs on main thread via idle_add):
if icon._quitting and not active:
    icon._stop_event.set()
    icon._loop.quit()  # exits as soon as inactive is detected, not when stop returns
```

### WAYLAND_DISPLAY is not inherited by systemd user services automatically

Systemd user services start before any shell session runs, so `WAYLAND_DISPLAY` is not set
in their environment. This project uses `dbus-update-activation-environment --all --systemd`
in `bash.nix` to propagate session variables into the systemd user manager when a shell
opens. The service then uses `PassEnvironment = [ "WAYLAND_DISPLAY" ]` to inherit it.

This means the tray icon requires a shell to have opened at least once before it can connect
to the Wayland display. On a clean boot where the tray starts before any terminal, it will
restart (via `Restart=on-failure`) until `WAYLAND_DISPLAY` is available.

### COSMIC calls optional dbusmenu methods

COSMIC calls `AboutToShow` and `ProvideXdgActivationToken` before interacting with the menu.
These must be implemented (even as no-ops) and declared in the introspection XML, otherwise
COSMIC returns an `UnknownMethod` error and may not display the menu.

### pystray does not work on Wayland

`pystray` uses XEmbed-based system trays (X11) or GTK AppIndicator. Neither works on a pure
Wayland COSMIC session. The correct approach is to implement the StatusNotifierItem D-Bus
protocol directly using `dbus-python`.
