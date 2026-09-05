import io
import json
import socket
import subprocess
import sys
import threading
import unittest
import uuid
from unittest.mock import Mock, patch
from urllib.request import Request, urlopen
from urllib.error import HTTPError

from idom_remote import PowerController, RemoteApplication, magic_packet, send_wake, shutdown_windows, validate_config

TOKEN = "a" * 64


class ManualTimer:
    def __init__(self, delay, callback, args):
        self.delay, self.callback, self.args = delay, callback, args
    def start(self):
        pass
    def cancel(self):
        pass
    def fire(self):
        self.callback(*self.args)


class RemoteTests(unittest.TestCase):
    def setUp(self):
        self.now = 100.0
        self.shutdown = Mock()
        self.wake = Mock()
        self.config = dict(role="pc", token=TOKEN, name="Test PC")
        self.controller = PowerController(self.config, shutdown=self.shutdown, wake=self.wake,
                                          clock=lambda: self.now, timer_factory=ManualTimer)
        self.app = RemoteApplication(self.controller)

    def tearDown(self):
        self.controller.close()

    def call(self, action, request_id=None):
        return self.controller.command(action, request_id or str(uuid.uuid4()))

    def request(self, path="/v1/status", method="GET", token=TOKEN, body=None, **extra):
        data = json.dumps(body if body is not None else {"requestID": str(uuid.uuid4())}).encode()
        env = dict(PATH_INFO=path, REQUEST_METHOD=method, HTTP_AUTHORIZATION="Bearer " + token,
                   CONTENT_TYPE="application/json", CONTENT_LENGTH=str(len(data)))
        env["wsgi.input"] = io.BytesIO(data)
        env.update(extra)
        result = []
        payload = b"".join(self.app(env, lambda status, headers: result.append((status, headers))))
        return int(result[0][0].split()[0]), json.loads(payload)

    def test_authentication_required_for_status_and_commands(self):
        for path, method in [("/v1/status", "GET"), ("/v1/shutdown", "POST"), ("/v1/cancel", "POST")]:
            self.assertEqual(self.request(path, method, token="wrong")[0], 401)
        self.assertIsNone(self.controller.pending)

    def test_status_does_not_schedule_anything(self):
        code, status = self.request()
        self.assertEqual(code, 200)
        self.assertEqual(status["protocolVersion"], 1)
        self.assertEqual(status["role"], "pc")
        self.assertIsNone(status["shutdownRemaining"])
        self.shutdown.assert_not_called()

    def test_shutdown_countdown_then_exactly_one_execution(self):
        self.assertEqual(self.call("shutdown")[0], 200)
        self.assertEqual(self.controller.status()["shutdownRemaining"], 30)
        self.shutdown.assert_not_called()
        timer = self.controller.timer
        self.now += 10
        self.assertEqual(self.controller.status()["shutdownRemaining"], 20)
        self.call("shutdown")
        self.assertIs(self.controller.timer, timer)
        timer.fire()
        timer.fire()
        self.shutdown.assert_called_once()

    def test_cancellation_invalidates_already_queued_callback(self):
        self.call("shutdown")
        old_timer = self.controller.timer
        self.assertEqual(self.call("cancel")[0], 200)
        self.call("shutdown")
        old_timer.fire()
        self.shutdown.assert_not_called()
        self.controller.timer.fire()
        self.shutdown.assert_called_once()

    def test_repeated_request_does_not_reschedule_after_cancel(self):
        request_id = str(uuid.uuid4())
        original = self.call("shutdown", request_id)
        self.call("cancel")
        self.assertEqual(self.call("shutdown", request_id), original)
        self.assertIsNone(self.controller.pending)
        self.assertEqual(self.call("cancel", request_id)[0], 409)

    def test_shutdown_failure_visible_in_status(self):
        self.shutdown.side_effect = OSError("failure")
        self.call("shutdown")
        self.controller.timer.fire()
        self.assertIn("non ha accettato", self.controller.status()["lastError"])

    def test_simulated_mode_cannot_shutdown(self):
        self.controller.simulated = True
        self.call("shutdown")
        self.controller.timer.fire()
        self.shutdown.assert_not_called()
        self.assertTrue(self.controller.status()["simulated"])

    def test_role_separation(self):
        self.assertEqual(self.call("wake")[0], 404)
        self.config.update(role="wake", mac="02:11:22:33:44:55", network="192.168.1.20/24")
        self.assertEqual(self.call("shutdown")[0], 404)
        self.assertEqual(self.call("cancel")[0], 404)
        self.assertEqual(self.call("wake")[0], 200)
        self.wake.assert_called_once_with(self.config)

    def test_wake_rate_limit(self):
        self.config.update(role="wake", mac="02:11:22:33:44:55", network="192.168.1.20/24")
        self.call("wake")
        self.assertEqual(self.call("wake")[0], 429)
        self.now += 11
        self.assertEqual(self.call("wake")[0], 200)

    def test_browser_origin_get_commands_and_unknown_routes_rejected(self):
        self.assertEqual(self.request(HTTP_ORIGIN="https://example.org")[0], 403)
        self.assertEqual(self.request("/v1/shutdown")[0], 405)
        self.assertEqual(self.request("/v1/exec", "POST")[0], 404)

    def test_request_body_must_be_small_json_uuid_only(self):
        for body in [{}, [], {"requestID": "bad"}, {"requestID": 12}, {"requestID": str(uuid.uuid4()), "command": "anything"}]:
            self.assertEqual(self.request("/v1/shutdown", "POST", body=body)[0], 400)
        self.assertEqual(self.request("/v1/shutdown", "POST", CONTENT_LENGTH="99999")[0], 413)
        self.assertEqual(self.request("/v1/shutdown", "POST", CONTENT_TYPE="text/plain")[0], 415)

    def test_magic_packet_exact_format(self):
        raw = bytes.fromhex("021122334455")
        self.assertEqual(magic_packet("02:11:22:33:44:55"), b"\xff" * 6 + raw * 16)
        self.assertEqual(len(magic_packet("02-11-22-33-44-55")), 102)
        for mac in ["bad", "FF:FF:FF:FF:FF:FF", "00:00:00:00:00:00", "01:11:22:33:44:55"]:
            with self.assertRaises(ValueError):
                magic_packet(mac)

    def test_wake_uses_fixed_local_interface_and_broadcast(self):
        config = dict(mac="02:11:22:33:44:55", network="192.168.50.10/24")
        with patch("idom_remote.socket.socket") as factory:
            sock = factory.return_value.__enter__.return_value
            send_wake(config)
            sock.bind.assert_called_once_with(("192.168.50.10", 0))
            self.assertEqual(sock.sendto.call_count, 3)
            sock.sendto.assert_called_with(magic_packet(config["mac"]), ("192.168.50.255", 9))

    def test_shutdown_command_never_forces_open_documents(self):
        with patch("idom_remote.sys.platform", "win32"), patch("idom_remote.subprocess.run") as run:
            shutdown_windows()
            args = run.call_args.args[0]
            self.assertNotIn("/f", args)
            self.assertEqual(args[args.index("/t") + 1], "0")
            self.assertFalse(run.call_args.kwargs["shell"])

    def test_invalid_config_rejected(self):
        for change in [dict(token="short"), dict(role="shell"), dict(name=""),
                       dict(role="wake", mac="02:11:22:33:44:55", network="8.8.8.8/24")]:
            with self.assertRaises(ValueError):
                validate_config(dict(self.config, **change))

    def test_real_http_server_roundtrip_without_power_actions(self):
        from waitress.server import create_server
        server = create_server(self.app, host="127.0.0.1", port=0, threads=1)
        thread = threading.Thread(target=server.run, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.effective_port}"
        try:
            with self.assertRaises(HTTPError) as failure:
                urlopen(base + "/v1/status", timeout=3)
            self.assertEqual(failure.exception.code, 401)
            request = Request(base + "/v1/status", headers={"Authorization": "Bearer " + TOKEN})
            with urlopen(request, timeout=3) as response:
                self.assertEqual(json.load(response)["name"], "Test PC")
            for action in ["shutdown", "cancel"]:
                request = Request(base + "/v1/" + action, method="POST",
                                  data=json.dumps({"requestID": str(uuid.uuid4())}).encode(),
                                  headers={"Authorization": "Bearer " + TOKEN, "Content-Type": "application/json"})
                with urlopen(request, timeout=3) as response:
                    self.assertEqual(response.status, 200)
            self.shutdown.assert_not_called()
            self.assertIsNone(self.controller.pending)
        finally:
            server.close()
            server.task_dispatcher.shutdown()
            thread.join(timeout=3)


if __name__ == "__main__":
    unittest.main()
