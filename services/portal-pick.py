#!/usr/bin/env python3
# Picker de arquivo/pasta via xdg-desktop-portal (org.freedesktop.portal.FileChooser),
# chamado pelo PortalService.qml (campos "dir"/"image" da SettingsWindow). Usa o MESMO
# portal já citado no ThemeExport (xdg-desktop-portal-gtk/gnome, o que estiver registrado
# como backend) — não é um GtkFileChooser à parte, é o diálogo nativo do sistema.
#
# argv: modo ("folder" | "image" | "file") [titulo] [pasta inicial]
# stdout: caminho local escolhido (uma linha) ou nada, se cancelado/erro.
import sys
import os
from urllib.parse import urlparse, unquote

import gi
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib

IMAGE_PATTERNS = ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.tif", "*.tiff", "*.avif", "*.jxl"]


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "file"
    title = sys.argv[2] if len(sys.argv) > 2 else "Escolher"
    start_dir = sys.argv[3] if len(sys.argv) > 3 else ""

    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)

    opts = {"handle_token": GLib.Variant("s", "qspick%d" % os.getpid())}
    if mode == "folder":
        opts["directory"] = GLib.Variant("b", True)
    if mode == "image":
        opts["filters"] = GLib.Variant("a(sa(us))", [("Imagens", [(0, p) for p in IMAGE_PATTERNS])])
    if start_dir and os.path.isdir(start_dir):
        opts["current_folder"] = GLib.Variant.new_bytestring(start_dir.encode("utf-8"))

    try:
        reply = bus.call_sync(
            "org.freedesktop.portal.Desktop",
            "/org/freedesktop/portal/desktop",
            "org.freedesktop.portal.FileChooser",
            "OpenFile",
            GLib.Variant("(ssa{sv})", ("", title, opts)),
            GLib.VariantType("(o)"),
            Gio.DBusCallFlags.NONE, -1, None)
    except GLib.Error as e:
        sys.stderr.write("portal-pick: %s\n" % e)
        sys.exit(1)

    request_path = reply.unpack()[0]
    loop = GLib.MainLoop()
    picked = {}

    def on_response(connection, sender_name, object_path, interface_name, signal_name, params):
        code, results = params.unpack()
        if code == 0:
            uris = results.get("uris") or []
            if uris:
                picked["uri"] = uris[0]
        loop.quit()

    bus.signal_subscribe(
        "org.freedesktop.portal.Desktop", "org.freedesktop.portal.Request", "Response",
        request_path, None, Gio.DBusSignalFlags.NONE, on_response)

    GLib.timeout_add_seconds(300, loop.quit)  # trava de segurança se o Response nunca vier
    loop.run()

    uri = picked.get("uri")
    if not uri:
        return
    parsed = urlparse(uri)
    if parsed.scheme == "file":
        print(unquote(parsed.path))


if __name__ == "__main__":
    main()
