"""iDom power companion. Only loopback HTTP; expose through private Tailscale Serve."""
import argparse
import hmac
import ipaddress
import json
import math
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import sys
import threading
import time
import uuid


def validate_config(config):
    if config.get("role") not in ("pc", "wake"):
        raise ValueError("Ruolo non valido: pc oppure wake.")
    if not re.fullmatch(r"[a-f0-9]{64}", config.get("token", "")):
        raise ValueError("La chiave deve contenere 64 caratteri esadecimali minuscoli.")
    if not isinstance(config.get("name"), str) or not 1 <= len(config["name"]) <= 80:
        raise ValueError("Nome non valido.")
    if config["role"] == "wake":
        magic_packet(config.get("mac", ""))
        interface = ipaddress.IPv4Interface(config.get("network", ""))
        if not interface.ip.is_private or interface.ip.is_loopback or interface.ip.is_link_local:
            raise ValueError("Usa l'indirizzo IPv4 privato del ponte con prefisso, ad esempio 192.168.1.20/24.")
        if interface.network.prefixlen < 16 or interface.network.prefixlen > 30:
            raise ValueError("Prefisso di rete supportato: da /16 a /30.")
        if interface.ip in (interface.network.network_address, interface.network.broadcast_address):
            raise ValueError("Indirizzo del ponte non valido.")
    return config


def magic_packet(mac):
    if not re.fullmatch(r"(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}|(?:[0-9a-fA-F]{2}-){5}[0-9a-fA-F]{2}", mac):
        raise ValueError("Indirizzo MAC Ethernet non valido.")
    raw = bytes.fromhex(mac.replace(":", "").replace("-", ""))
    if raw[0] & 1 or raw == b"\0" * 6:
        raise ValueError("Serve il MAC unicast della scheda Ethernet del PC.")
    return b"\xff" * 6 + raw * 16


def send_wake(config):
    interface = ipaddress.IPv4Interface(config["network"])
    packet = magic_packet(config["mac"])
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.bind((str(interface.ip), 0))
        for _ in range(3):
            sock.sendto(packet, (str(interface.network.broadcast_address), 9))


def shutdown_windows():
    if sys.platform != "win32":
        raise RuntimeError("Lo spegnimento reale è supportato solo su Windows.")
    # The countdown is managed here: Windows /t > 0 implies /f (forced close).
    # /t 0, without /f, lets applications with unsaved work block shutdown.
    system_root = os.environ.get("SystemRoot", r"C:\Windows")
    subprocess.run([str(Path(system_root) / "System32" / "shutdown.exe"),
                    "/s", "/t", "0", "/d", "p:0:0"],
                   check=True, timeout=15, capture_output=True, shell=False)


class PowerController:
    def __init__(self, config, simulated=False, shutdown=shutdown_windows, wake=send_wake,
                 clock=time.monotonic, timer_factory=threading.Timer):
        self.config = validate_config(config)
        self.simulated = simulated
        self.shutdown = shutdown
        self.wake = wake
        self.clock = clock
        self.timer_factory = timer_factory
        self.lock = threading.RLock()
        self.pending = None
        self.timer = None
        self.generation = None
        self.executing = False
        self.last_error = None
        self.receipts = {}
        self.last_wake = None

    def status(self):
        with self.lock:
            return dict(protocolVersion=1, role=self.config["role"], name=self.config["name"],
                        simulated=self.simulated,
                        shutdownRemaining=None if self.pending is None else max(0, math.ceil(self.pending - self.clock())),
                        lastError=self.last_error)

    def command(self, action, request_id):
        with self.lock:
            now = self.clock()
            self.receipts = {key: value for key, value in self.receipts.items() if now - value[0] < 600}
            if request_id in self.receipts:
                _, old_action, result = self.receipts[request_id]
                return result if old_action == action else (409, {"message": "Identificatore già usato per un altro comando."})
            if len(self.receipts) >= 1024:
                return 429, {"message": "Troppi comandi. Attendi e riprova."}
            if action == "wake" and self.config["role"] == "wake":
                if self.last_wake is not None and now - self.last_wake < 10:
                    return 429, {"message": "Segnale già inviato. Attendi prima di riprovare."}
                try:
                    if not self.simulated:
                        self.wake(self.config)
                except OSError:
                    return 503, {"message": "Segnale non inviato. Controlla l'indirizzo di rete del ponte."}
                self.last_wake = now
                result = 200, {"message": "Prova: nessun segnale inviato." if self.simulated else "Segnale di accensione inviato. L'avvio non è ancora confermato: attendi che il PC torni raggiungibile."}
            elif action == "shutdown" and self.config["role"] == "pc":
                if self.executing:
                    return 409, {"message": "Spegnimento già consegnato a Windows."}
                if self.pending is None:
                    self.pending = now + 30
                    self.last_error = None
                    self.generation = uuid.uuid4().hex
                    self.timer = self.timer_factory(30, self._finish, args=(self.generation,))
                    self.timer.daemon = True
                    self.timer.start()
                result = 200, {"message": "Prova: conto alla rovescia di 30 secondi, senza spegnimento reale." if self.simulated else "Spegnimento programmato tra circa 30 secondi. Puoi ancora annullarlo."}
            elif action == "cancel" and self.config["role"] == "pc":
                if self.executing:
                    return 409, {"message": "Il comando è già stato consegnato a Windows: non è più annullabile da iDom."}
                if self.timer:
                    self.timer.cancel()
                self.timer = None
                self.generation = None
                self.pending = None
                result = 200, {"message": "Nessuno spegnimento programmato da iDom: il conto alla rovescia è annullato."}
            else:
                return 404, {"message": "Comando non disponibile su questo componente."}
            self.receipts[request_id] = (now, action, result)
            return result

    def _finish(self, generation):
        with self.lock:
            if self.generation != generation:
                return
            self.pending = None
            self.generation = None
            self.executing = True
        error = None
        try:
            if not self.simulated:
                self.shutdown()
        except (OSError, RuntimeError, subprocess.SubprocessError):
            error = "Windows non ha accettato lo spegnimento. Controlla permessi e applicazioni aperte sul PC."
        finally:
            with self.lock:
                self.executing = False
                self.last_error = error

    def close(self):
        with self.lock:
            self.generation = None
            self.pending = None
            if self.timer:
                self.timer.cancel()


class RemoteApplication:
    def __init__(self, controller):
        self.controller = controller

    def __call__(self, environ, start_response):
        status, payload = self.dispatch(environ)
        data = json.dumps(payload, ensure_ascii=True).encode("utf-8")
        reasons = {200: "OK", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden",
                   404: "Not Found", 405: "Method Not Allowed", 409: "Conflict",
                   413: "Content Too Large", 415: "Unsupported Media Type", 429: "Too Many Requests", 503: "Service Unavailable"}
        start_response(f"{status} {reasons[status]}", [("Content-Type", "application/json"),
                       ("Content-Length", str(len(data))), ("Cache-Control", "no-store"),
                       ("X-Content-Type-Options", "nosniff")])
        return [data]

    def dispatch(self, env):
        # Not a browser API; prohibit cross-site requests even if a local page learns the URL.
        if env.get("HTTP_ORIGIN"):
            return 403, {"message": "Richiesta browser non consentita."}
        supplied = env.get("HTTP_AUTHORIZATION", "").encode("utf-8")
        expected = ("Bearer " + self.controller.config["token"]).encode("ascii")
        if not hmac.compare_digest(supplied, expected):
            return 401, {"message": "Chiave non valida."}
        path, method = env.get("PATH_INFO", ""), env.get("REQUEST_METHOD", "")
        if path == "/v1/status" and method == "GET":
            return 200, self.controller.status()
        if path not in ("/v1/wake", "/v1/shutdown", "/v1/cancel"):
            return 404, {"message": "Operazione non disponibile."}
        if method != "POST":
            return 405, {"message": "Serve POST."}
        if env.get("CONTENT_TYPE", "").split(";")[0] != "application/json":
            return 415, {"message": "Serve JSON."}
        try:
            length = int(env.get("CONTENT_LENGTH") or "0")
            if not 1 <= length <= 256:
                return 413, {"message": "Dimensione richiesta non valida."}
            body = json.loads(env["wsgi.input"].read(length))
            if not isinstance(body, dict) or set(body) != {"requestID"}:
                raise ValueError()
            request_id = str(uuid.UUID(body["requestID"]))
        except (ValueError, TypeError, AttributeError, KeyError):
            return 400, {"message": "Identificatore richiesta non valido."}
        return self.controller.command(path.rsplit("/", 1)[1], request_id)


def main():
    parser = argparse.ArgumentParser(description="iDom PC Remote · componente privato Tailscale")
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--init", choices=["pc", "wake"])
    parser.add_argument("--name", default=socket.gethostname())
    parser.add_argument("--mac")
    parser.add_argument("--network", help="IPv4 del ponte/prefisso, ad esempio 192.168.1.20/24")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--check", action="store_true", help="Valida senza avviare il servizio")
    args = parser.parse_args()
    if args.init:
        config = validate_config(dict(role=args.init, name=args.name, token=secrets.token_hex(32), mac=args.mac, network=args.network))
        # Exclusive creation: rerunning setup cannot silently rotate an existing phone's key.
        fd = os.open(args.config, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(config, stream, indent=2)
        print("Configurazione creata. La chiave privata si trova nel file locale; non condividerlo.")
        return
    config = validate_config(json.loads(args.config.read_text(encoding="utf-8-sig")))
    if config["role"] == "pc" and sys.platform != "win32" and not args.dry_run:
        parser.error("La modalità PC reale richiede Windows. Usa --dry-run per le prove.")
    if args.check:
        print("Configurazione valida.")
        return
    from waitress import serve
    controller = PowerController(config, simulated=args.dry_run)
    try:
        serve(RemoteApplication(controller), host="127.0.0.1", port=47321,
              threads=4, connection_limit=32, channel_timeout=15,
              max_request_body_size=256, max_request_header_size=8192,
              clear_untrusted_proxy_headers=True, expose_tracebacks=False)
    finally:
        controller.close()


if __name__ == "__main__":
    main()
