#!/usr/bin/env python3
"""
Clavis Bluetooth Pairing Agent (BlueZ D-Bus Agent)
Provides automatic authorization and confirmation for Bluetooth pairing operations.
"""

import sys
import os
import signal
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

AGENT_PATH = "/org/clavis/bluetooth/agent"
CAPABILITY = "DisplayYesNo"

class BluetoothAgent(dbus.service.Object):
    def __init__(self, bus, path):
        super().__init__(bus, path)

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Release(self):
        print("[BluetoothAgent] Released by BlueZ", flush=True)

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        print(f"[BluetoothAgent] AuthorizeService: {device} {uuid}", flush=True)
        return

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        print(f"[BluetoothAgent] RequestPinCode for {device}", flush=True)
        return "0000"

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        print(f"[BluetoothAgent] RequestPasskey for {device}", flush=True)
        return dbus.UInt32(0)

    @dbus.service.method("org.bluez.Agent1", in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        print(f"[BluetoothAgent] DisplayPasskey: device={device} passkey={passkey:06d} entered={entered}", flush=True)

    @dbus.service.method("org.bluez.Agent1", in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        print(f"[BluetoothAgent] DisplayPinCode: device={device} pin={pincode}", flush=True)

    @dbus.service.method("org.bluez.Agent1", in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        print(f"[BluetoothAgent] RequestConfirmation: device={device} passkey={passkey:06d} -> auto confirmed", flush=True)
        return

    @dbus.service.method("org.bluez.Agent1", in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        print(f"[BluetoothAgent] RequestAuthorization for {device} -> authorized", flush=True)
        return

    @dbus.service.method("org.bluez.Agent1", in_signature="", out_signature="")
    def Cancel(self):
        print("[BluetoothAgent] Pairing request cancelled", flush=True)

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    loop = GLib.MainLoop()

    try:
        bus = dbus.SystemBus()
    except Exception as e:
        print(f"[BluetoothAgent] Failed to connect to SystemBus: {e}", file=sys.stderr, flush=True)
        sys.exit(1)

    agent = BluetoothAgent(bus, AGENT_PATH)

    def register():
        try:
            manager = dbus.Interface(bus.get_object("org.bluez", "/org/bluez"), "org.bluez.AgentManager1")
            manager.RegisterAgent(AGENT_PATH, CAPABILITY)
            manager.RequestDefaultAgent(AGENT_PATH)
            print(f"[BluetoothAgent] Registered as default agent with capability '{CAPABILITY}'", flush=True)
            return True
        except dbus.DBusException as e:
            print(f"[BluetoothAgent] Registration error: {e}", file=sys.stderr, flush=True)
            return False

    register()

    def name_owner_changed(name, old_owner, new_owner):
        if name == "org.bluez" and new_owner != "":
            print("[BluetoothAgent] BlueZ daemon restarted, re-registering agent...", flush=True)
            register()

    bus.add_signal_receiver(
        name_owner_changed,
        signal_name="NameOwnerChanged",
        dbus_interface="org.freedesktop.DBus"
    )

    def sig_handler(sig, frame):
        loop.quit()

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    loop.run()

if __name__ == "__main__":
    main()
