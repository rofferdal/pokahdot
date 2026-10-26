from __future__ import annotations

import json
import subprocess
import unittest
from unittest.mock import patch

from tools.web_lan.network import local_candidate, network_addresses


class NetworkTests(unittest.TestCase):
    @patch("tools.web_lan.network.os.uname")
    @patch("tools.web_lan.network.subprocess.run")
    def test_macos_maps_active_addresses_to_hardware_service_names(self, run, uname) -> None:
        uname.return_value.sysname = "Darwin"
        ifconfig = """lo0: flags=8049<UP,LOOPBACK,RUNNING>\n\tinet 127.0.0.1 netmask 0xff000000\nen7: flags=8863<UP,BROADCAST>\n\tinet 192.168.39.105 netmask 0xffffff00\nen0: flags=8863<UP,BROADCAST>\n\tinet 10.0.0.9 netmask 0xffffff00\n"""
        hardware = """Hardware Port: USB 10/100/1000 LAN\nDevice: en7\nEthernet Address: aa\n\nHardware Port: Wi-Fi\nDevice: en0\nEthernet Address: bb\n"""
        run.side_effect = [subprocess.CompletedProcess([], 0, ifconfig, ""),
                           subprocess.CompletedProcess([], 0, hardware, "")]
        rows = network_addresses()
        self.assertEqual(rows, [
            {"interface": "en0", "address": "10.0.0.9", "label": "Wi-Fi"},
            {"interface": "en7", "address": "192.168.39.105", "label": "USB 10/100/1000 LAN"},
        ])

    @patch("tools.web_lan.network.os.uname")
    @patch("tools.web_lan.network.subprocess.run")
    def test_linux_uses_ip_json_output(self, run, uname) -> None:
        uname.return_value.sysname = "Linux"
        output = [{"ifname": "lo", "addr_info": [{"family": "inet", "local": "127.0.0.1"}]},
                  {"ifname": "wlan0", "addr_info": [{"family": "inet", "local": "10.1.2.3"}]}]
        run.return_value = subprocess.CompletedProcess([], 0, json.dumps(output), "")
        self.assertEqual(network_addresses(), [
            {"interface": "wlan0", "address": "10.1.2.3", "label": "wlan0"},
        ])

    @patch("tools.web_lan.network.network_addresses")
    def test_wildcard_prefers_private_lan_address_but_specific_bind_is_kept(self, addresses) -> None:
        addresses.return_value = [
            {"interface": "en0", "address": "192.168.1.4", "label": "Wi-Fi"},
            {"interface": "en7", "address": "169.254.2.1", "label": "USB"},
        ]
        self.assertEqual(local_candidate("0.0.0.0"), "192.168.1.4")
        self.assertEqual(local_candidate("10.0.0.4"), "10.0.0.4")
        self.assertEqual(local_candidate("127.0.0.1"), "127.0.0.1")


if __name__ == "__main__":
    unittest.main()
