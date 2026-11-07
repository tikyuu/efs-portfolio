import sys
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import main
from fastapi.testclient import TestClient


class FileApiTests(unittest.TestCase):
    def setUp(self):
        self.temporary = TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.shared = self.directory / "shared"
        self.shared.mkdir()
        self.static = self.directory / "static"
        self.static.mkdir()
        (self.static / "index.html").write_text('<html><script src="/assets/app.js"></script></html>')
        (self.static / "assets").mkdir()
        (self.static / "assets/app.js").write_text('document.title = "Shared";')
        self.outside = self.directory / "outside.txt"
        self.outside.write_text("outside")
        self.patch_shared = patch.object(main, "SHARED_DIR", self.shared)
        self.patch_static = patch.object(main, "STATIC_DIR", self.static)
        self.patch_shared.start()
        self.patch_static.start()
        self.addCleanup(self.patch_shared.stop)
        self.addCleanup(self.patch_static.stop)
        self.client = TestClient(main.app)
        self.addCleanup(self.client.close)

    def upload(self, filename="売上.csv", content=b"name,sales\napple,100\n"):
        return self.client.post("/upload/", files={"file": (filename, content)})

    def test_upload_list_and_download(self):
        content = b"name,sales\napple,100\n"
        response = self.upload(content=content)
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json(), {"filename": "売上.csv", "size": len(content)})
        self.assertEqual((self.shared / "売上.csv").read_bytes(), content)
        self.assertEqual(self.client.get("/files/").json(), {"files": [{"name": "売上.csv", "size": len(content)}]})
        downloaded = self.client.get("/files/売上.csv")
        self.assertEqual(downloaded.status_code, 200)
        self.assertEqual(downloaded.content, content)
        self.assertTrue(downloaded.headers["content-disposition"].startswith("attachment;"))

    def test_overwrite_is_rejected(self):
        self.assertEqual(self.upload(content=b"original").status_code, 201)
        self.assertEqual(self.upload(content=b"replacement").status_code, 409)
        self.assertEqual((self.shared / "売上.csv").read_bytes(), b"original")
        self.assertFalse(list(self.shared.glob(".upload-*")))

    def test_invalid_names_are_rejected(self):
        for name in ("../escape.txt", "/absolute.txt", "nested/file.txt", "nested\\file.txt", ".hidden", ".."):
            with self.subTest(name=name):
                self.assertEqual(self.upload(name).status_code, 400)
        self.assertEqual(list(self.shared.iterdir()), [])

    def test_limit_and_missing_upload(self):
        with patch.object(main, "MAX_UPLOAD_BYTES", 8):
            self.assertEqual(self.upload("ok.txt", b"12345678").status_code, 201)
            self.assertEqual(self.upload("large.txt", b"123456789").status_code, 413)
        self.assertFalse((self.shared / "large.txt").exists())
        self.assertEqual(self.client.post("/upload/").status_code, 422)

    def test_write_failure_cleanup(self):
        with patch.object(main.os, "link", side_effect=OSError("write failure")):
            self.assertEqual(self.upload().status_code, 503)
        self.assertEqual(list(self.shared.iterdir()), [])

    def test_simultaneous_upload_does_not_overwrite(self):
        def send(content):
            with TestClient(main.app) as client:
                return client.post("/upload/", files={"file": ("same.txt", content)}).status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            statuses = list(pool.map(send, (b"first", b"second")))
        self.assertEqual(sorted(statuses), [201, 409])
        self.assertIn((self.shared / "same.txt").read_bytes(), (b"first", b"second"))
        self.assertFalse(list(self.shared.glob(".upload-*")))

    def test_listing_hides_partial_files_directories_and_symlinks(self):
        (self.shared / "b.txt").write_text("b")
        (self.shared / "a.txt").write_text("a")
        (self.shared / ".upload-partial").write_text("partial")
        (self.shared / "directory").mkdir()
        (self.shared / "link.txt").symlink_to(self.outside)
        names = [file["name"] for file in self.client.get("/files/").json()["files"]]
        self.assertEqual(names, ["a.txt", "b.txt"])
        for name in ("link.txt", "directory", "missing.txt"):
            self.assertEqual(self.client.get(f"/files/{name}").status_code, 404)
        self.assertEqual(self.client.get("/files/.upload-partial").status_code, 400)

    def test_uploaded_html_is_a_download(self):
        self.assertEqual(self.upload("sample.html", b"<script>alert(1)</script>").status_code, 201)
        response = self.client.get("/files/sample.html")
        self.assertEqual(response.headers["content-type"], "application/octet-stream")
        self.assertEqual(response.headers["x-content-type-options"], "nosniff")
        self.assertTrue(response.headers["content-disposition"].startswith("attachment;"))

    def test_storage_unavailable_does_not_break_health(self):
        with patch.object(main, "SHARED_DIR", self.directory / "missing"):
            self.assertEqual(self.upload().status_code, 503)
            self.assertEqual(self.client.get("/files/").status_code, 503)
            self.assertEqual(self.client.get("/files/test.txt").status_code, 503)
            self.assertEqual(self.client.get("/health").json(), {"status": "ok"})
            self.assertFalse((self.directory / "missing").exists())

    def test_frontend_and_asset_delivery(self):
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)
        self.assertIn("text/html", response.headers["content-type"])
        self.assertEqual(self.client.get("/assets/app.js").text, 'document.title = "Shared";')
        self.assertEqual(self.client.get("/assets/missing.js").status_code, 404)
        self.assertEqual(self.client.get("/assets/%2e%2e/%2e%2e/outside.txt").status_code, 404)
        (self.static / "assets/leak.txt").symlink_to(self.outside)
        self.assertEqual(self.client.get("/assets/leak.txt").status_code, 404)
        with patch.object(main, "STATIC_DIR", self.directory / "not-built"):
            self.assertEqual(self.client.get("/").status_code, 503)
            self.assertEqual(self.client.get("/health").status_code, 200)


if __name__ == "__main__":
    unittest.main()
