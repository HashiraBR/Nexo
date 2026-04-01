#!/usr/bin/env python3
import argparse
import base64
import hashlib
import json


def build_payload(args):
    demo = 1 if args.demo else 0
    return (
        f"a={int(args.account)}|"
        f"e={args.expiration}|"
        f"s={args.symbols}|"
        f"t={args.timeframes}|"
        f"l={float(args.max_lot)}|"
        f"g={args.strategies}|"
        f"d={demo}"
    )


def sign_payload(secret, payload):
    digest = hashlib.sha256((secret + payload).encode("utf-8")).digest()
    short = digest[:16]
    return base64.urlsafe_b64encode(short).decode("utf-8").rstrip("=")


def main():
    parser = argparse.ArgumentParser(description="Generate EA license key")
    parser.add_argument("--secret", required=True, help="License secret (same as LICENSE_SECRET)")
    parser.add_argument("--account", required=True, help="Account login number")
    parser.add_argument("--expiration", required=True, help="Expiration YYYY-MM-DD")
    parser.add_argument("--symbols", required=True, help="CSV symbols (supports prefix like WIN*)")
    parser.add_argument("--timeframes", required=True, help="CSV timeframes (e.g., M5,M15)")
    parser.add_argument("--max-lot", required=True, help="Max lot (number)")
    parser.add_argument("--strategies", required=True, help="CSV strategies or *")
    parser.add_argument("--demo", action="store_true", help="Generate demo-only license")
    args = parser.parse_args()

    payload = build_payload(args)
    signature = sign_payload(args.secret, payload)
    payload_b64 = base64.urlsafe_b64encode(payload.encode("utf-8")).decode("utf-8").rstrip("=")
    b64 = payload_b64 + "." + signature

    print("payload:", payload)
    print("signature:", signature)
    print("key:", b64)


if __name__ == "__main__":
    main()
