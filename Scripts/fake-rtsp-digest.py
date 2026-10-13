#!/usr/bin/env python3
"""Spike only: a fake RTSP server that checks Digest credentials.

Answers every request without credentials with a Digest challenge like the
DVR's (no qop), and checks the Authorization header of the next request
against USER/PASSWORD below. Prints MATCH or MISMATCH, then answers 404.

Usage: Scripts/fake-rtsp-digest.py [port]   (default 8554)
"""
import hashlib
import re
import socketserver
import sys

USER = "tester"
PASSWORD = "a@b:c/d#e"
REALM = "Login to fake"
NONCE = "0123456789abcdef0123456789abcdef"


def md5(text):
    return hashlib.md5(text.encode()).hexdigest()


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        while True:
            lines = []
            while True:
                line = self.rfile.readline()
                if not line:
                    return
                line = line.decode(errors="replace").rstrip("\r\n")
                if not line:
                    break
                lines.append(line)
            method = lines[0].split(" ")[0]
            cseq = next((l.split(":", 1)[1].strip() for l in lines if l.lower().startswith("cseq:")), "0")
            auth = next((l.split(":", 1)[1].strip() for l in lines if l.lower().startswith("authorization:")), None)
            if auth is None:
                print(f"{method}: no credentials, sending challenge", flush=True)
                self.reply(f"401 Unauthorized", cseq, f'WWW-Authenticate: Digest realm="{REALM}", nonce="{NONCE}"')
                continue
            fields = dict(re.findall(r'(\w+)="([^"]*)"', auth))
            expected = md5(f"{md5(f'{USER}:{REALM}:{PASSWORD}')}:{NONCE}:{md5(method + ':' + fields.get('uri', ''))}")
            result = "MATCH" if fields.get("response") == expected and fields.get("username") == USER else "MISMATCH"
            print(f"{method}: username={fields.get('username')!r} {result}", flush=True)
            self.reply("404 Not Found", cseq)
            return

    def reply(self, status, cseq, *headers):
        text = "\r\n".join([f"RTSP/1.0 {status}", f"CSeq: {cseq}", *headers]) + "\r\n\r\n"
        self.wfile.write(text.encode())


socketserver.TCPServer.allow_reuse_address = True

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8554
    with socketserver.TCPServer(("127.0.0.1", port), Handler) as server:
        server.serve_forever()
