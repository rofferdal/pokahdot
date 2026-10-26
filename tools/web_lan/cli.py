"""Build and serve the production game for local Wi-Fi testing."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .build import BuildError, build_project, resolve_output


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("build", help="Check and export the current production game")
    build.add_argument("--godot", default="godot", help="Godot 4.7.2 executable")
    build.add_argument("--output", type=Path, default=Path("localtmp/web-lan"))
    serve = commands.add_parser("serve", help="Serve verified builds in the foreground")
    serve.add_argument("--output", type=Path, default=Path("localtmp/web-lan"))
    serve.add_argument("--bind", default="0.0.0.0")
    serve.add_argument("--port", type=int, default=8080)
    serve.add_argument("--cert", type=Path, help="Optional HTTPS certificate chain")
    serve.add_argument("--key", type=Path, help="Optional HTTPS private key")
    serve.add_argument("--ca-cert", type=Path, help="CA certificate used to verify HTTPS shutdown")
    serve.add_argument("--http", action="store_true", help="Explicit HTTP mode, useful for loopback diagnostics")
    tls = commands.add_parser("tls-init", help="Prepare a private local CA and HTTPS certificate")
    tls.add_argument("--output", type=Path, default=Path("localtmp/web-lan"))
    tls.add_argument("--address", action="append", required=True, help="LAN IPv4 address; repeat as needed")
    for command in ("status", "stop"):
        subcommand = commands.add_parser(command)
        subcommand.add_argument("--output", type=Path, default=Path("localtmp/web-lan"))
    commands.add_parser("network", help="List candidate LAN interfaces and addresses")
    args = parser.parse_args(argv)
    try:
        if args.command == "build":
            metadata = build_project(args.godot, args.output)
            print(json.dumps(metadata, indent=2))
        elif args.command == "network":
            from .network import network_addresses
            print(json.dumps(network_addresses(), indent=2))
        elif args.command == "tls-init":
            from .tls import create_certificates
            print(json.dumps(create_certificates(args.output, args.address), indent=2))
        else:
            from .server import serve, server_status, stop_server
            if args.command == "serve":
                if args.http and any((args.cert, args.key, args.ca_cert)):
                    raise BuildError("Use --http or HTTPS certificate options, not both.")
                if not args.http and not any((args.cert, args.key, args.ca_cert)):
                    directory = resolve_output(args.output) / "tls"
                    args.cert, args.key, args.ca_cert = (
                        directory / "server.pem", directory / "server.key", directory / "ca.pem"
                    )
                    if not all(path.is_file() for path in (args.cert, args.key, args.ca_cert)):
                        raise BuildError("Prepare HTTPS first with tls-init --address <LAN-IP>, then trust its CA. "
                                         "Use --http --bind 127.0.0.1 only for an explicit loopback diagnostic.")
                serve(args.output, args.bind, args.port, args.cert, args.key, ca_cert=args.ca_cert)
            elif args.command == "stop":
                print(json.dumps(stop_server(args.output), indent=2))
            else:
                print(json.dumps(server_status(args.output), indent=2))
    except KeyboardInterrupt:
        return 0
    except (BuildError, OSError, ValueError) as error:
        print(f"web-lan: {error}", file=sys.stderr)
        return 1
    return 0
