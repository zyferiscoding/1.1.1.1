#!/usr/bin/env python3
"""Generate the 1.1.1.1 encrypted-DNS configuration profiles for iPad/iPhone.

Run from the repo root:  python3 tools/make_profiles.py
Output goes to docs/profiles/. UUIDs are derived deterministically, so
re-running only changes files whose content actually changed.
"""
import plistlib
import uuid
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "docs" / "profiles"
NS = uuid.UUID("6b1d4a52-1111-4111-8111-111111111111")

VARIANTS = {
    "standard": {
        "title": "1.1.1.1",
        "blurb": "Fast, private DNS. No filtering.",
        "doh": "https://cloudflare-dns.com/dns-query",
        "dot": "one.one.one.one",
        "ips": ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"],
    },
    "malware": {
        "title": "1.1.1.1 for Families (Malware)",
        "blurb": "Blocks known malware and phishing domains.",
        "doh": "https://security.cloudflare-dns.com/dns-query",
        "dot": "security.cloudflare-dns.com",
        "ips": ["1.1.1.2", "1.0.0.2", "2606:4700:4700::1112", "2606:4700:4700::1002"],
    },
    "family": {
        "title": "1.1.1.1 for Families (Malware + Adult)",
        "blurb": "Blocks malware, phishing and adult content.",
        "doh": "https://family.cloudflare-dns.com/dns-query",
        "dot": "family.cloudflare-dns.com",
        "ips": ["1.1.1.3", "1.0.0.3", "2606:4700:4700::1113", "2606:4700:4700::1003"],
    },
}


def profile(key, v, proto):
    ident = f"com.oneonevpn.dns.{key}.{proto}"
    if proto == "https":
        dns = {"DNSProtocol": "HTTPS", "ServerURL": v["doh"], "ServerAddresses": v["ips"]}
        label = "DNS over HTTPS"
    else:
        dns = {"DNSProtocol": "TLS", "ServerName": v["dot"], "ServerAddresses": v["ips"]}
        label = "DNS over TLS"
    name = f"{v['title']} ({label})"
    payload = {
        "PayloadType": "com.apple.dnsSettings.managed",
        "PayloadVersion": 1,
        "PayloadIdentifier": ident + ".payload",
        "PayloadUUID": str(uuid.uuid5(NS, ident + ".payload")).upper(),
        "PayloadDisplayName": name,
        "DNSSettings": dns,
    }
    return {
        "PayloadType": "Configuration",
        "PayloadVersion": 1,
        "PayloadIdentifier": ident,
        "PayloadUUID": str(uuid.uuid5(NS, ident)).upper(),
        "PayloadDisplayName": name,
        "PayloadDescription": f"{v['blurb']} Encrypts every DNS lookup on this device with Cloudflare {label}.",
        "PayloadOrganization": "1.1.1.1 for iPad",
        "PayloadRemovalDisallowed": False,
        "PayloadContent": [payload],
    }


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for key, v in VARIANTS.items():
        for proto in ("https", "tls"):
            path = OUT / f"1.1.1.1-{key}-{proto}.mobileconfig"
            with path.open("wb") as f:
                plistlib.dump(profile(key, v, proto), f, sort_keys=True)
            print("wrote", path.relative_to(OUT.parent.parent))


if __name__ == "__main__":
    main()
