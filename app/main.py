import os
import tempfile
from pathlib import Path

from fastapi import FastAPI, HTTPException, UploadFile
from fastapi.responses import FileResponse

app = FastAPI()
SHARED_DIR = Path("/mnt/shared")
STATIC_DIR = Path(__file__).resolve().parent / "static"
MAX_UPLOAD_BYTES = 10 * 1024 * 1024


def valid_filename(filename: str | None) -> str:
    """保存先の外や、一時ファイルを指定する名前を受け付けない。"""
    if (
        not filename
        or filename.startswith(".")
        or any(character in filename for character in ("/", "\\", "\x00"))
        or any(ord(character) < 32 for character in filename)
        or len(filename.encode("utf-8")) > 255
    ):
        raise HTTPException(status_code=400, detail="ファイル名が不正です。")
    return filename


def shared_directory() -> Path:
    # マウント前に代わりのローカルフォルダを自動作成しない。
    if not SHARED_DIR.is_dir():
        raise HTTPException(status_code=503, detail="共有の保存先を利用できません。")
    return SHARED_DIR


@app.get("/health")
def health():
    # アプリが応答できるかを見る。EFS接続の検査ではない。
    return {"status": "ok"}


@app.post("/upload/", status_code=201)
def upload(file: UploadFile):
    filename = valid_filename(file.filename)
    directory = shared_directory()
    content = file.file.read(MAX_UPLOAD_BYTES + 1)
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="ファイルは10 MiB以内にしてください。")

    temporary_path = None
    try:
        # 完成前のファイルを一覧に出さず、失敗時は一時ファイルを消す。
        with tempfile.NamedTemporaryFile(dir=directory, prefix=".upload-", delete=False) as temporary:
            temporary_path = Path(temporary.name)
            temporary.write(content)
        # 同じEFS内で公開名を作る。同名なら失敗し、既存ファイルを上書きしない。
        os.link(temporary_path, directory / filename)
    except FileExistsError:
        raise HTTPException(status_code=409, detail="同名のファイルが既に存在します。") from None
    except OSError:
        raise HTTPException(status_code=503, detail="ファイルを保存できませんでした。") from None
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)

    return {"filename": filename, "size": len(content)}


@app.get("/files/")
def list_files():
    directory = shared_directory()
    files = []
    try:
        for path in sorted(directory.iterdir(), key=lambda item: item.name.casefold()):
            if path.name.startswith(".") or path.is_symlink() or not path.is_file():
                continue
            try:
                valid_filename(path.name)
            except HTTPException:
                continue
            try:
                files.append({"name": path.name, "size": path.stat().st_size})
            except FileNotFoundError:
                # 一覧取得中に別タスクが削除したファイルはスキップする。
                continue
    except OSError:
        raise HTTPException(status_code=503, detail="ファイル一覧を取得できませんでした。") from None
    return {"files": files}


@app.get("/files/{filename}")
def download(filename: str):
    filename = valid_filename(filename)
    path = shared_directory() / filename
    if path.is_symlink() or not path.is_file():
        raise HTTPException(status_code=404, detail="ファイルが見つかりません。")
    # アップロードされたHTML等も、画面として実行せず添付ファイルで返す。
    return FileResponse(
        path,
        filename=filename,
        media_type="application/octet-stream",
        headers={"X-Content-Type-Options": "nosniff"},
    )


def frontend_file(relative_path: Path) -> FileResponse:
    if not STATIC_DIR.is_dir():
        raise HTTPException(status_code=503, detail="画面用ファイルがまだ配置されていません。")
    root = STATIC_DIR.resolve()
    path = (root / relative_path).resolve()
    if not path.is_relative_to(root) or not path.is_file():
        raise HTTPException(status_code=404, detail="画面用ファイルが見つかりません。")
    return FileResponse(path, headers={"X-Content-Type-Options": "nosniff"})


@app.get("/", include_in_schema=False)
def frontend():
    return frontend_file(Path("index.html"))


@app.get("/assets/{asset_path:path}", include_in_schema=False)
def frontend_asset(asset_path: str):
    return frontend_file(Path("assets") / asset_path)
