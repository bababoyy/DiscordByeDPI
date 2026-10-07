"""Exercise the real C diagnostic against local SOCKS fixtures, without Internet."""
import ctypes
import os
import pathlib
import socket
import subprocess
import tempfile
import threading
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class ProbeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        path = pathlib.Path(cls.tmp.name) / "probe.so"
        subprocess.run([os.environ.get("CC", "cc"), "-shared", "-fPIC", "-Wall",
                        "-Wextra", "-Werror", str(ROOT / "local_probe.c"),
                        "-o", str(path)], check=True)
        cls.library = ctypes.CDLL(str(path))
        cls.probe = cls.library.dbd_probe_socks5
        cls.probe.argtypes = [ctypes.c_ushort]
        cls.probe.restype = ctypes.c_int

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def fixture(self, reply):
        errors = []
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            listener.settimeout(4)
            port = listener.getsockname()[1]

            def serve():
                try:
                    with listener.accept()[0] as client:
                        client.settimeout(4)
                        data = b""
                        while len(data) < 3:
                            chunk = client.recv(3 - len(data))
                            if not chunk:
                                raise AssertionError("incomplete greeting")
                            data += chunk
                        if data != b"\x05\x01\x00":
                            raise AssertionError("wrong SOCKS greeting")
                        if reply:
                            client.sendall(reply)
                except Exception as exc:
                    errors.append(exc)

            thread = threading.Thread(target=serve)
            thread.start()
            result = self.probe(port)
            thread.join(5)
            self.assertFalse(thread.is_alive())
            self.assertEqual(errors, [])
            return result

    def test_socks5_no_auth(self):
        self.assertEqual(self.fixture(b"\x05\x00"), 0)

    def test_socks_auth_rejected(self):
        self.assertEqual(self.fixture(b"\x05\xff"), 4)

    def test_non_socks_listener(self):
        self.assertEqual(self.fixture(b"HT"), 4)

    def test_peer_closes(self):
        self.assertEqual(self.fixture(b""), 3)

    def test_no_listener(self):
        with socket.socket() as reservation:
            reservation.bind(("127.0.0.1", 0))
            self.assertEqual(self.probe(reservation.getsockname()[1]), 2)


if __name__ == "__main__":
    unittest.main()
