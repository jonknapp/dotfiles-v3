{
  inputs,
  ...
}:
{
  flake.modules.homeManager.nixToolbox =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Python environment for StatusNotifierItem (SNI) tray
      trayPython = pkgs.python3.withPackages (ps: [
        ps.dbus-python
        ps.pygobject3 # provides gi.repository.GLib for the D-Bus main loop
      ]);

      # StatusNotifierItem tray icon implemented directly over D-Bus.
      # No GTK, no Xorg — works natively on Wayland with any SNI-compatible panel.
      #
      # Protocol references:
      #   https://www.freedesktop.org/wiki/Specifications/StatusNotifierItem/
      #   https://freedesktop.org/wiki/Specifications/StatusNotifierItem/StatusNotifierItem/
      trayScript = pkgs.writeText "mock-service-tray.py" ''
        #!/usr/bin/env python3
        """
        StatusNotifierItem tray icon for mock-service.
        Registers on the session D-Bus, shows active/inactive status,
        and provides a Start / Stop context menu.
        """
        import subprocess
        import threading

        import dbus
        import dbus.service
        import dbus.mainloop.glib
        from gi.repository import GLib

        SERVICE_NAME = "mock-service.service"
        POLL_INTERVAL = 3  # seconds

        # Minimal PNG icons encoded inline as D-Bus byte arrays.
        # Each is a 16x16 ARGB image: a filled circle, green or grey.
        # Generated as (width, height, [(alpha, red, green, blue), ...]) per SNI spec.
        def _circle_pixmap(r, g, b):
            """Return an SNI-format icon: (width, height, data) where data is ARGB bytes."""
            size = 16
            cx, cy, radius = 8, 8, 6
            pixels = []
            for y in range(size):
                for x in range(size):
                    if (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2:
                        pixels += [255, r, g, b]  # ARGB
                    else:
                        pixels += [0, 0, 0, 0]    # transparent
            return dbus.Struct(
                (dbus.Int32(size), dbus.Int32(size),
                 dbus.Array(pixels, signature='y')),
                signature=None
            )

        ICON_ACTIVE   = [_circle_pixmap(80, 200, 80)]   # green
        ICON_INACTIVE = [_circle_pixmap(140, 140, 140)] # grey


        def run_systemctl(*args):
            result = subprocess.run(
                ["systemctl", "--user", *args],
                capture_output=True, text=True,
            )
            return result.returncode


        def is_active():
            return run_systemctl("is-active", "--quiet", SERVICE_NAME) == 0


        # D-Bus introspection XML for the StatusNotifierItem interface
        SNI_INTROSPECT = """
        <!DOCTYPE node PUBLIC
          "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
          "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
        <node>
          <interface name="org.kde.StatusNotifierItem">
            <property name="Category"         type="s" access="read"/>
            <property name="Id"               type="s" access="read"/>
            <property name="Title"            type="s" access="read"/>
            <property name="Status"           type="s" access="read"/>
            <property name="IconName"         type="s" access="read"/>
            <property name="IconPixmap"       type="a(iiay)" access="read"/>
            <property name="ToolTip"          type="(sa(iiay)ss)" access="read"/>
            <property name="ItemIsMenu"       type="b" access="read"/>
            <method name="ProvideXdgActivationToken">
              <arg direction="in" type="s" name="token"/>
            </method>
            <signal name="NewIcon"/>
            <signal name="NewStatus">
              <arg name="status" type="s"/>
            </signal>
          </interface>
          <interface name="org.freedesktop.DBus.Introspectable">
            <method name="Introspect">
              <arg direction="out" type="s"/>
            </method>
          </interface>
          <interface name="org.freedesktop.DBus.Properties">
            <method name="Get">
              <arg direction="in"  type="s" name="interface_name"/>
              <arg direction="in"  type="s" name="property_name"/>
              <arg direction="out" type="v" name="value"/>
            </method>
            <method name="GetAll">
              <arg direction="in"  type="s" name="interface_name"/>
              <arg direction="out" type="a{sv}" name="props"/>
            </method>
          </interface>
          <interface name="com.canonical.dbusmenu">
            <method name="GetLayout">
              <arg direction="in"  type="i"  name="parentId"/>
              <arg direction="in"  type="i"  name="recursionDepth"/>
              <arg direction="in"  type="as" name="propertyNames"/>
              <arg direction="out" type="u"  name="revision"/>
              <arg direction="out" type="(ia{sv}av)" name="layout"/>
            </method>
            <method name="Event">
              <arg direction="in" type="i"  name="id"/>
              <arg direction="in" type="s"  name="eventId"/>
              <arg direction="in" type="v"  name="data"/>
              <arg direction="in" type="u"  name="timestamp"/>
            </method>
            <method name="AboutToShow">
              <arg direction="in"  type="i" name="id"/>
              <arg direction="out" type="b" name="needUpdate"/>
            </method>
            <signal name="LayoutUpdated">
              <arg type="u" name="revision"/>
              <arg type="i" name="parent"/>
            </signal>
            <signal name="ItemActivationRequested">
              <arg type="i" name="id"/>
              <arg type="u" name="timestamp"/>
            </signal>
          </interface>
        </node>
        """

        MENU_REVISION = 1

        class TrayIcon(dbus.service.Object):
            def __init__(self, bus, loop, stop_event):
                self._active = is_active()
                self._stopping = False
                self._starting = False
                self._quitting = False
                self._menu_revision = MENU_REVISION
                self._loop = loop
                self._stop_event = stop_event
                bus_name = dbus.service.BusName(
                    "org.kde.StatusNotifierItem-mock-service",
                    bus=bus,
                    replace_existing=True,
                    allow_replacement=True,
                    do_not_queue=True,
                )
                super().__init__(bus_name, "/StatusNotifierItem")

            # ---- org.freedesktop.DBus.Introspectable ----

            @dbus.service.method("org.freedesktop.DBus.Introspectable",
                                 out_signature="s")
            def Introspect(self):
                return SNI_INTROSPECT

            # ---- org.freedesktop.DBus.Properties ----

            @dbus.service.method("org.freedesktop.DBus.Properties",
                                 in_signature="ss", out_signature="v")
            def Get(self, interface, prop):
                return self._get_props().get(prop, "")

            @dbus.service.method("org.freedesktop.DBus.Properties",
                                 in_signature="s", out_signature="a{sv}")
            def GetAll(self, interface):
                return self._get_props()

            def _get_props(self):
                status_str = "Active" if self._active else "Passive"
                if self._stopping:
                    label = "mock-service: stopping..."
                elif self._starting:
                    label = "mock-service: starting..."
                else:
                    label = "mock-service: " + ("active" if self._active else "inactive")
                icon_pixmap = ICON_ACTIVE if self._active else ICON_INACTIVE
                return {
                    "Category":   dbus.String("ApplicationStatus"),
                    "Id":         dbus.String("mock-service"),
                    "Title":      dbus.String(label),
                    "Status":     dbus.String(status_str),
                    "IconName":   dbus.String(""),
                    "IconPixmap": dbus.Array(icon_pixmap, signature="(iiay)"),
                    "ToolTip":    dbus.Struct(
                        ("", dbus.Array([], signature="(iiay)"), label, ""),
                        signature=None,
                    ),
                    "ItemIsMenu": dbus.Boolean(True),
                    "Menu":       dbus.ObjectPath("/StatusNotifierItem"),
                }

            # ---- SNI signals ----

            @dbus.service.signal("org.kde.StatusNotifierItem")
            def NewIcon(self): pass

            @dbus.service.signal("org.kde.StatusNotifierItem", signature="s")
            def NewStatus(self, status): pass

            def update_status(self, active):
                self._active = active
                self.NewIcon()
                self.NewStatus("Active" if active else "Passive")

            # ---- com.canonical.dbusmenu ----

            def _build_menu(self):
                active = self._active
                if self._stopping:
                    status_label = "mock-service: stopping..."
                elif self._starting:
                    status_label = "mock-service: starting..."
                else:
                    status_label = "mock-service: " + ("active" if active else "inactive")
                items = [
                    dbus.Struct((
                        dbus.Int32(1),
                        dbus.Dictionary({
                            "label":   dbus.String(status_label),
                            "enabled": dbus.Boolean(False),
                        }, signature="sv"),
                        dbus.Array([], signature="v"),
                    ), signature=None),
                    dbus.Struct((
                        dbus.Int32(2),
                        dbus.Dictionary({"type": dbus.String("separator")}, signature="sv"),
                        dbus.Array([], signature="v"),
                    ), signature=None),
                    dbus.Struct((
                        dbus.Int32(3),
                        dbus.Dictionary({"label": dbus.String("Start")}, signature="sv"),
                        dbus.Array([], signature="v"),
                    ), signature=None),
                    dbus.Struct((
                        dbus.Int32(4),
                        dbus.Dictionary({"label": dbus.String("Stop")}, signature="sv"),
                        dbus.Array([], signature="v"),
                    ), signature=None),
                    dbus.Struct((
                        dbus.Int32(5),
                        dbus.Dictionary({"type": dbus.String("separator")}, signature="sv"),
                        dbus.Array([], signature="v"),
                    ), signature=None),
                    dbus.Struct((
                        dbus.Int32(6),
                        dbus.Dictionary({"label": dbus.String("Quit")}, signature="sv"),
                        dbus.Array([], signature="v"),
                    ), signature=None),
                ]
                root = dbus.Struct((
                    dbus.Int32(0),
                    dbus.Dictionary({"children-display": dbus.String("submenu")}, signature="sv"),
                    dbus.Array(items, signature="v"),
                ), signature=None)
                return root

            @dbus.service.method("com.canonical.dbusmenu",
                                 in_signature="iias", out_signature="u(ia{sv}av)")
            def GetLayout(self, parentId, recursionDepth, propertyNames):
                return (dbus.UInt32(self._menu_revision), self._build_menu())

            @dbus.service.method("com.canonical.dbusmenu",
                                 in_signature="i", out_signature="b")
            def AboutToShow(self, id):
                return False  # no update needed

            # ---- org.kde.StatusNotifierItem ----

            @dbus.service.method("org.kde.StatusNotifierItem",
                                 in_signature="s")
            def ProvideXdgActivationToken(self, token):
                pass  # optional method, ignore

            @dbus.service.method("com.canonical.dbusmenu",
                                 in_signature="isvu")
            def Event(self, item_id, event_id, data, timestamp):
                if event_id != "clicked":
                    return
                if item_id == 3:
                    self._starting = True
                    self._menu_revision += 1
                    self.LayoutUpdated(self._menu_revision, 0)
                    self.NewIcon()
                    threading.Thread(
                        target=run_systemctl, args=("start", SERVICE_NAME), daemon=True
                    ).start()
                elif item_id == 4:
                    self._stopping = True
                    self._menu_revision += 1
                    self.LayoutUpdated(self._menu_revision, 0)
                    self.NewIcon()
                    threading.Thread(
                        target=run_systemctl, args=("stop", SERVICE_NAME), daemon=True
                    ).start()
                elif item_id == 6:
                    self._quitting = True
                    if is_active():
                        self._stopping = True
                        self._menu_revision += 1
                        self.LayoutUpdated(self._menu_revision, 0)
                        self.NewIcon()
                        threading.Thread(
                            target=run_systemctl, args=("stop", SERVICE_NAME), daemon=True
                        ).start()
                    else:
                        self._stop_event.set()
                        GLib.idle_add(self._loop.quit)

            @dbus.service.signal("com.canonical.dbusmenu", signature="ui")
            def LayoutUpdated(self, revision, parent): pass

            @dbus.service.signal("com.canonical.dbusmenu", signature="iu")
            def ItemActivationRequested(self, id, timestamp): pass


        def do_update(icon):
            active = is_active()
            changed = active != icon._active
            if icon._stopping and not active:
                icon._stopping = False
            if icon._starting and active:
                icon._starting = False
            if changed:
                icon.update_status(active)
                icon._menu_revision += 1
                icon.LayoutUpdated(icon._menu_revision, 0)
            if icon._quitting and not active:
                icon._stop_event.set()
                icon._loop.quit()
            return False  # do not repeat; poll_loop reschedules via idle_add


        def poll_loop(icon, stop_event):
            while not stop_event.wait(POLL_INTERVAL):
                GLib.idle_add(do_update, icon)


        def main():
            dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
            bus = dbus.SessionBus()
            loop = GLib.MainLoop()

            stop_event = threading.Event()
            icon = TrayIcon(bus, loop, stop_event)

            # Register with the COSMIC StatusNotifierWatcher.
            # COSMIC uses its own bus name but implements the standard KDE interface.
            try:
                watcher = bus.get_object(
                    "com.system76.CosmicStatusNotifierWatcher",
                    "/StatusNotifierWatcher",
                )
                watcher.RegisterStatusNotifierItem(
                    "/StatusNotifierItem",
                    dbus_interface="org.kde.StatusNotifierWatcher",
                )
            except dbus.DBusException as e:
                print(f"Warning: could not register with StatusNotifierWatcher: {e}")

            threading.Thread(target=poll_loop, args=(icon, stop_event), daemon=True).start()
            loop.run()


        if __name__ == "__main__":
            main()
      '';

      # Wrap the tray script into a proper bin so it is on PATH inside the container
      trayBin = pkgs.writeShellScriptBin "mock-service-tray" ''
        exec ${trayPython}/bin/python3 ${trayScript} "$@"
      '';

      # The mock service loop as a bin so toolbox can find it by name on PATH
      mockServiceBin = pkgs.writeShellScriptBin "mock-service-run" ''
        while true; do
          echo "mock-service heartbeat $(date --iso-8601=seconds)" \
            | ${pkgs.systemd}/bin/systemd-cat --identifier=mock-service --priority=info
          sleep 10
        done
      '';

    in
    {
      home.packages = [
        trayBin
        mockServiceBin
      ];

      # -----------------------------------------------------------------
      # Mock long-lived service
      # Loops forever: sleeps 10 s then logs a heartbeat via systemd-cat.
      # ExecStart uses toolbox so the binary is found in the Nix profile
      # inside the container; systemd-cat is on the host on Fedora Atomic.
      # -----------------------------------------------------------------
      systemd.user.services.mock-service = {
        Unit = {
          Description = "Mock long-lived service (heartbeat every 10 s)";
        };

        Service = {
          Type = "simple";
          ExecStart = "toolbox --container ${config.programs.nixToolbox.containerName} run mock-service-run";
          Restart = "on-failure";
        };
      };

      # -----------------------------------------------------------------
      # Tray icon service
      # Starts after tray.target so the system tray is available.
      # -----------------------------------------------------------------
      systemd.user.services.mock-service-tray = {
        Unit = {
          Description = "System tray icon for mock-service";
          Requires = [ "tray.target" ];
          After = [ "tray.target" ];
        };

        Service = {
          ExecStart = ''
            toolbox --container ${config.programs.nixToolbox.containerName} run mock-service-tray
          '';
          Type = "exec";
          Restart = "on-failure";
          RestartSec = "3s";
          # WAYLAND_DISPLAY is inherited from the systemd user manager environment,
          # populated by dbus-update-activation-environment --all --systemd in bash.nix.
          PassEnvironment = [ "WAYLAND_DISPLAY" ];
        };

        Install = {
          WantedBy = [ "tray.target" ];
        };
      };

      # -----------------------------------------------------------------
      # Desktop entry — lets the COSMIC launcher start the tray manually
      # -----------------------------------------------------------------
      xdg.desktopEntries.mock-service-tray = {
        name = "Mock Service";
        exec = "systemctl --user start --no-block mock-service-tray.service";
        terminal = false;
        categories = [ "Utility" ];
        icon = "application-x-executable";
        comment = "Start/stop the mock service from the system tray";
      };
    };
}
