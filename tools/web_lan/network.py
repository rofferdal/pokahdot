"""Network interface discovery for the local Web development server."""

from __future__ import annotations

import ipaddress
import json
import os
import socket
import subprocess


def _interface_labels() -> dict[str, str]:
    if os.uname().sysname != "Darwin":
        return {}
    try:
        result = subprocess.run(["/usr/sbin/networksetup", "-listallhardwareports"],
                                capture_output=True, text=True, check=False, timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return {}
    labels: dict[str, str] = {}
    current = ""
    for line in result.stdout.splitlines():
        if line.startswith("Hardware Port:"):
            current = line.partition(":")[2].strip()
        elif line.startswith("Device:") and current:
            labels[line.partition(":")[2].strip()] = current
            current = ""
    return labels


def network_addresses() -> list[dict]:
    """List IPv4 interface addresses and, on macOS, their service labels."""
    system = os.uname().sysname
    found: list[tuple[str, str]] = []
    if system == "Darwin":
        try:
            result = subprocess.run(["/sbin/ifconfig"], capture_output=True, text=True,
                                    check=False, timeout=5)
            interface = ""
            for line in result.stdout.splitlines():
                if line and not line[0].isspace() and ":" in line:
                    interface = line.split(":", 1)[0]
                elif interface and line.strip().startswith("inet "):
                    address = line.strip().split()[1]
                    try:
                        if not ipaddress.ip_address(address).is_loopback:
                            found.append((interface, address))
                    except ValueError:
                        pass
        except (OSError, subprocess.TimeoutExpired):
            pass
    else:
        try:
            result = subprocess.run(["ip", "-j", "addr"], capture_output=True, text=True,
                                    check=False, timeout=5)
            if result.returncode == 0:
                for interface in json.loads(result.stdout):
                    for item in interface.get("addr_info", []):
                        address = item.get("local", "")
                        if item.get("family") == "inet" and address and not ipaddress.ip_address(address).is_loopback:
                            found.append((interface.get("ifname", ""), address))
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass
        if not found:
            for _index, name in socket.if_nameindex():
                try:
                    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    import fcntl
                    import struct
                    address = socket.inet_ntoa(fcntl.ioctl(
                        probe.fileno(), 0x8915, struct.pack("256s", name[:15].encode()))[20:24])
                    probe.close()
                    if not ipaddress.ip_address(address).is_loopback:
                        found.append((name, address))
                except OSError:
                    continue
    labels = _interface_labels()
    return [{"interface": interface, "address": address,
             "label": labels.get(interface, interface)}
            for interface, address in sorted(set(found))]


def local_candidate(bind: str) -> str:
    """Choose a likely Wi-Fi/LAN IPv4 candidate for a wildcard listener."""
    try:
        if ipaddress.ip_address(bind).is_loopback:
            return bind
    except ValueError:
        pass
    addresses = network_addresses()
    if bind != "0.0.0.0":
        return bind
    for row in addresses:
        try:
            if ipaddress.ip_address(row["address"]).is_private:
                return row["address"]
        except ValueError:
            continue
    return "127.0.0.1"
