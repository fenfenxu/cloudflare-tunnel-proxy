#!/usr/bin/env python3
"""Minimal HTTP CONNECT proxy bound to 127.0.0.1 only.
Optional Basic auth via PROXY_USER / PROXY_PASS or --auth user:pass.
"""
from __future__ import annotations

import argparse
import base64
import os
import select
import socket
import socketserver
import sys
import threading
from typing import Optional, Tuple

BUF = 65536
CONNECT_TIMEOUT = 20


def parse_auth(raw: Optional[str]) -> Optional[Tuple[str, str]]:
    if not raw:
        return None
    if ":" not in raw:
        raise SystemExit("auth must be user:pass")
    u, p = raw.split(":", 1)
    return u, p


class Handler(socketserver.StreamRequestHandler):
    timeout = 60
    auth: Optional[Tuple[str, str]] = None

    def handle(self) -> None:
        try:
            first = self.rfile.readline(65536)
            if not first:
                return
            line = first.decode("iso-8859-1", errors="replace").rstrip("\r\n")
            parts = line.split(" ")
            if len(parts) < 2:
                self._reply(400, b"Bad Request")
                return
            method, target = parts[0].upper(), parts[1]
            headers = {}
            while True:
                h = self.rfile.readline(65536)
                if not h or h in (b"\r\n", b"\n"):
                    break
                try:
                    k, v = h.decode("iso-8859-1", errors="replace").split(":", 1)
                    headers[k.strip().lower()] = v.strip()
                except ValueError:
                    pass

            if self.auth is not None and not self._check_auth(headers):
                self.wfile.write(
                    b"HTTP/1.1 407 Proxy Authentication Required\r\n"
                    b"Proxy-Authenticate: Basic realm=\"cf-box-proxy\"\r\n"
                    b"Content-Length: 0\r\n"
                    b"Connection: close\r\n\r\n"
                )
                return

            if method != "CONNECT":
                # Allow a tiny health check without CONNECT
                if method == "GET" and target in ("/", "/healthz"):
                    body = b"ok\n"
                    self.wfile.write(
                        b"HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n"
                        + f"Content-Length: {len(body)}\r\nConnection: close\r\n\r\n".encode()
                        + body
                    )
                    return
                self._reply(405, b"Method Not Allowed (CONNECT only)")
                return

            host, port = self._split_hostport(target)
            try:
                remote = socket.create_connection((host, port), timeout=CONNECT_TIMEOUT)
            except OSError as e:
                self._reply(502, f"Bad Gateway: {e}".encode())
                return

            self.wfile.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
            self.wfile.flush()
            self._pipe(self.connection, remote)
        except Exception:
            return

    def _check_auth(self, headers: dict) -> bool:
        assert self.auth is not None
        raw = headers.get("proxy-authorization") or headers.get("authorization")
        if not raw or not raw.lower().startswith("basic "):
            return False
        try:
            decoded = base64.b64decode(raw.split(" ", 1)[1].strip()).decode("utf-8")
        except Exception:
            return False
        if ":" not in decoded:
            return False
        u, p = decoded.split(":", 1)
        return u == self.auth[0] and p == self.auth[1]

    @staticmethod
    def _split_hostport(target: str) -> Tuple[str, int]:
        if target.startswith("["):
            # [ipv6]:port
            end = target.find("]")
            host = target[1:end]
            port = int(target[end + 2 :]) if end + 1 < len(target) and target[end + 1] == ":" else 443
            return host, port
        if ":" in target:
            host, port_s = target.rsplit(":", 1)
            return host, int(port_s)
        return target, 443

    def _reply(self, code: int, body: bytes) -> None:
        reason = {400: "Bad Request", 405: "Method Not Allowed", 502: "Bad Gateway"}.get(code, "Error")
        self.wfile.write(
            f"HTTP/1.1 {code} {reason}\r\nContent-Length: {len(body)}\r\nConnection: close\r\n\r\n".encode()
            + body
        )

    @staticmethod
    def _pipe(a: socket.socket, b: socket.socket) -> None:
        sockets = [a, b]
        try:
            while True:
                r, _, x = select.select(sockets, [], sockets, 300)
                if x or not r:
                    break
                for s in r:
                    other = b if s is a else a
                    data = s.recv(BUF)
                    if not data:
                        return
                    other.sendall(data)
        finally:
            try:
                a.close()
            except OSError:
                pass
            try:
                b.close()
            except OSError:
                pass


class ThreadedServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


def main() -> None:
    ap = argparse.ArgumentParser(description="127.0.0.1-only HTTP CONNECT proxy")
    ap.add_argument("--listen", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=17897)
    ap.add_argument("--auth", default=os.environ.get("PROXY_AUTH") or "")
    args = ap.parse_args()
    if args.listen not in ("127.0.0.1", "::1"):
        raise SystemExit("refusing to bind non-loopback address")
    auth = parse_auth(args.auth) if args.auth else parse_auth(
        f"{os.environ.get('PROXY_USER','')}:{os.environ.get('PROXY_PASS','')}"
        if os.environ.get("PROXY_USER") and os.environ.get("PROXY_PASS")
        else None
    )
    Handler.auth = auth
    with ThreadedServer((args.listen, args.port), Handler) as srv:
        print(
            f"cf-box-proxy listening on {args.listen}:{args.port} auth={'on' if auth else 'off'}",
            flush=True,
        )
        try:
            srv.serve_forever()
        except KeyboardInterrupt:
            pass


if __name__ == "__main__":
    main()
