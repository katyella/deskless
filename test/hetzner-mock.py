"""A tiny stand-in for the Hetzner Cloud API, enough for deskless's laptop commands.

Usage: python3 hetzner-mock.py PORT
Accepts the token "good". Starts with one server, "other-box", that deskless didn't make.
"""
import base64
import hashlib
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

servers = {7: {"id": 7, "name": "other-box", "labels": {}, "status": "running",
               "public_net": {"ipv4": {"ip": "192.0.2.7"}},
               "server_type": {"name": "cpx22"}, "datacenter": {"location": {"name": "hel1"}}}}
keys = []
pricing = {"pricing": {"currency": "USD", "vat_rate": "0.000000",
                       "server_types": [{"name": "cx23", "prices": [{"location": "hel1", "price_monthly": {"gross": "6.4900000000000000"}}]}],
                       "primary_ips": [{"type": "ipv4", "prices": [{"location": "hel1", "price_monthly": {"gross": "0.6000000000000000"}}]}]}}


class Handler(BaseHTTPRequestHandler):
    def send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(data)

    def authorized(self):
        if self.headers.get("Authorization") == "Bearer good":
            return True
        self.send(401, {"error": {"code": "unauthorized", "message": "unable to authenticate"}})
        return False

    def do_GET(self):
        if not self.authorized():
            return
        url = urlparse(self.path)
        q = parse_qs(url.query)
        if url.path == "/v1/servers":
            found = list(servers.values())
            if "name" in q:
                found = [s for s in found if s["name"] == q["name"][0]]
            if "label_selector" in q:
                found = [s for s in found if q["label_selector"][0] in s["labels"]]
            return self.send(200, {"servers": found})
        if url.path == "/v1/pricing":
            return self.send(200, pricing)
        if url.path == "/v1/ssh_keys":
            return self.send(200, {"ssh_keys": [k for k in keys if k["fingerprint"] == q.get("fingerprint", [""])[0]]})
        self.send(404, {"error": {"message": "not found"}})

    def do_POST(self):
        if not self.authorized():
            return
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if self.path == "/v1/ssh_keys":
            raw = base64.b64decode(body["public_key"].split()[1])
            key = {"id": 99, "name": body["name"], "fingerprint": ":".join(f"{b:02x}" for b in hashlib.md5(raw).digest())}
            keys.append(key)
            return self.send(201, {"ssh_key": key})
        if self.path == "/v1/servers":
            if body["image"] == "nope":
                return self.send(422, {"error": {"code": "invalid_input", "message": "image nope not found"}})
            server = {"id": 42, "name": body["name"], "labels": body["labels"], "status": "initializing",
                      "public_net": {"ipv4": {"ip": "192.0.2.42"}},  # TEST-NET: never answers SSH
                      "server_type": {"name": body["server_type"]}, "datacenter": {"location": {"name": body["location"]}}}
            servers[42] = server
            return self.send(201, {"server": server})
        self.send(404, {"error": {"message": "not found"}})

    def do_DELETE(self):
        if not self.authorized():
            return
        servers.pop(int(self.path.rsplit("/", 1)[1]), None)
        self.send(200, {"action": {"status": "running"}})

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
