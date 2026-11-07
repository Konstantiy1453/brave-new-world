# -*- coding: utf-8 -*-
r"""下载并校验资产运输片段，恢复原始 ZIP；仅依赖 Python 3 标准库。

PowerShell: python .\RECEIVE_ASSETS.py --download
仅本地合并: python .\RECEIVE_ASSETS.py --assemble-only
不会解压、执行模型、改动游戏或删除下载片段。完整校验后才生成正式 ZIP。
"""

import argparse
import hashlib
from http.client import HTTPException
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError
from urllib.parse import quote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import uuid


REPOSITORY = "Konstantiy1453/brave-new-world"
RELEASE_TAG = "art-assets-20261107"
DOWNLOAD_PREFIX = "https://github.com/{}/releases/download/{}/".format(REPOSITORY, RELEASE_TAG)
MANIFEST_NAME = "TRANSPORT_MANIFEST.json"
MAX_ATTEMPTS = 3
RETRY_DELAY_SECONDS = 2
CHUNK_BYTES = 1024 * 1024
MANIFEST_LIMIT = 8 * 1024 * 1024


class ReceiverError(Exception):
    """可直接展示给接收者的校验或下载错误。"""


def say(message):
    try:
        print(message, flush=True)
    except UnicodeEncodeError:
        # Some Windows redirected consoles use cp950/cp1252. Logging must not
        # interrupt a download or prevent a completed file from being checked.
        raw = getattr(sys.stdout, "buffer", None)
        if raw is not None:
            raw.write((str(message) + "\n").encode("utf-8"))
            raw.flush()
        else:
            print(str(message).encode("ascii", "backslashreplace").decode("ascii"), flush=True)


def safe_basename(value):
    if (not isinstance(value, str) or not value or value in (".", "..")
            or value.endswith((".", " "))
            or any(ord(ch) < 32 or ch in '/\\:*?"<>|' for ch in value)):
        raise ReceiverError("不安全的文件名 / unsafe basename: {!r}".format(value))
    stem = value.split(".", 1)[0].upper()
    if stem in {"CON", "PRN", "AUX", "NUL"} or re.fullmatch(r"(?:COM|LPT)[1-9]", stem):
        raise ReceiverError("禁止 Windows 保留文件名: {}".format(value))
    return value


def validate_url(url, name):
    expected = DOWNLOAD_PREFIX + quote(safe_basename(name), safe="")
    if not isinstance(url, str) or url != expected:
        raise ReceiverError("下载 URL 必须属于固定仓库和 Release: {}".format(name))
    return url


def _size_sha(item, label):
    size = item.get("bytes")
    digest = item.get("sha256")
    if type(size) is not int or size <= 0:
        raise ReceiverError("清单大小必须是正整数: {}".format(label))
    if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
        raise ReceiverError("清单 SHA256 无效: {}".format(label))


def validate_manifest(value):
    if not isinstance(value, dict) or not isinstance(value.get("archives"), list) or not value["archives"]:
        raise ReceiverError("清单必须包含非空 archives 数组")
    archive_names, part_names = set(), set()
    for archive in value["archives"]:
        if not isinstance(archive, dict):
            raise ReceiverError("archive 必须是对象")
        name = safe_basename(archive.get("filename"))
        if not name.lower().endswith(".zip") or name.casefold() in archive_names:
            raise ReceiverError("ZIP 文件名错误或重复: {}".format(name))
        archive_names.add(name.casefold())
        _size_sha(archive, name)
        parts = archive.get("parts")
        if not isinstance(parts, list) or not parts:
            raise ReceiverError("每个 archive 必须列出非空 parts")
        for index, part in enumerate(parts, 1):
            if not isinstance(part, dict):
                raise ReceiverError("part 必须是对象")
            part_name = safe_basename(part.get("name"))
            expected = name if len(parts) == 1 and part_name == name else name + ".{:03d}".format(index)
            if part_name != expected or part_name.casefold() in part_names:
                raise ReceiverError("片段名称、顺序或唯一性错误: {}".format(part_name))
            part_names.add(part_name.casefold())
            _size_sha(part, part_name)
            validate_url(part.get("url"), part_name)
        if sum(part["bytes"] for part in parts) != archive["bytes"]:
            raise ReceiverError("片段大小总和与 ZIP 大小不一致: {}".format(name))
        if len(parts) == 1 and parts[0]["sha256"].lower() != archive["sha256"].lower():
            raise ReceiverError("单文件 ZIP 与 part 的 SHA256 不一致: {}".format(name))
    return value


def file_matches(path, size, digest):
    path = Path(path)
    if not path.is_file() or path.is_symlink() or path.stat().st_size != size:
        return False
    actual = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(CHUNK_BYTES), b""):
            actual.update(block)
    return actual.hexdigest() == digest.lower()


def _preserve(path, reason="bad"):
    """保留原始字节；不会删除坏文件或未完成片段。"""
    path = Path(path)
    if not path.exists() and not path.is_symlink():
        return None
    if path.is_dir() and not path.is_symlink():
        raise ReceiverError("同名目录阻止文件写入，保持该目录: {}".format(path))
    saved = path.with_name(path.name + ".{}-{}-{}".format(
        reason, time.strftime("%Y%m%dT%H%M%S", time.gmtime()), uuid.uuid4().hex[:8]))
    path.rename(saved)
    say("保留原文件 / preserved: {}".format(saved.name))
    return saved


def _install_verified(temp, target, size, digest):
    """只有已核验的候选文件可以到达这里；不覆盖已验证目标。"""
    if target.exists() or target.is_symlink():
        if file_matches(target, size, digest):
            return target
        _preserve(target)
    # Windows rename is non-overwriting; on other platforms hard-link creation
    # provides equivalent exclusive installation before removing the temp name.
    if os.name == "nt":
        temp.rename(target)
    else:
        os.link(temp, target)
        temp.unlink()
    return target


class _HttpsReleaseRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        parsed = urlsplit(newurl)
        host = parsed.hostname or ""
        # GitHub release URLs normally redirect to its HTTPS asset CDN.
        if (parsed.scheme != "https" or parsed.username or parsed.password
                or parsed.port not in (None, 443)
                or not (host == "github.com" or host.endswith(".githubusercontent.com"))):
            raise ReceiverError("拒绝非 GitHub HTTPS 下载重定向")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _open_url(request):
    return build_opener(_HttpsReleaseRedirect()).open(request, timeout=60)


def _request(url, offset=0):
    headers = {"User-Agent": "BNW-Asset-Receiver/1.0", "Accept-Encoding": "identity"}
    if offset:
        headers["Range"] = "bytes={}-".format(offset)
    return Request(url, headers=headers)


def download_part(part, downloads):
    name = safe_basename(part["name"])
    _size_sha(part, name)
    validate_url(part["url"], name)
    downloads = Path(downloads)
    downloads.mkdir(parents=True, exist_ok=True)
    target, temp = downloads / name, downloads / (name + ".part")
    size, digest = part["bytes"], part["sha256"]
    if file_matches(target, size, digest):
        say("已验证，跳过下载 / PASS cached: {}".format(name))
        return target
    if target.exists() or target.is_symlink():
        _preserve(target)
    if temp.is_symlink():
        raise ReceiverError("拒绝向符号链接写入: {}".format(temp))
    last_error = None
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            if temp.exists() and temp.stat().st_size >= size:
                if file_matches(temp, size, digest):
                    return _install_verified(temp, target, size, digest)
                _preserve(temp)
            offset = temp.stat().st_size if temp.exists() else 0
            say("下载 {}/{}: {}  起点 {} / {} bytes".format(attempt, MAX_ATTEMPTS, name, offset, size))
            with _open_url(_request(part["url"], offset)) as response:
                status = response.getcode()
                if status == 206:
                    match = re.fullmatch(r"bytes (\d+)-(\d+)/(\d+)", response.headers.get("Content-Range", ""))
                    if not match or int(match[1]) != offset or int(match[3]) != size or not offset <= int(match[2]) < size:
                        raise ReceiverError("Content-Range 不匹配，拒绝追加: {}".format(name))
                    mode = "ab" if offset else "wb"
                elif status == 200:
                    # A server may ignore Range. Keep the old partial as evidence
                    # and write the complete response from byte zero, never append.
                    if offset:
                        _preserve(temp, "restart")
                        say("服务器返回 200；从头写入，不追加 / restarting from byte zero")
                    offset, mode = 0, "wb"
                else:
                    raise ReceiverError("不支持的 HTTP 状态: {}".format(status))
                count, last_progress = offset, time.monotonic()
                with temp.open(mode) as stream:
                    while True:
                        block = response.read(CHUNK_BYTES)
                        if not block:
                            break
                        if count + len(block) > size:
                            raise ReceiverError("下载内容超过清单声明的大小: {}".format(name))
                        stream.write(block)
                        count += len(block)
                        if time.monotonic() - last_progress >= 15:
                            say("  {:.1f}%  {} / {} bytes".format(100.0 * count / size, count, size))
                            last_progress = time.monotonic()
            if temp.stat().st_size != size:
                raise ReceiverError("响应未完成，保留 .part 以供续传: {}".format(name))
            if not file_matches(temp, size, digest):
                _preserve(temp)
                raise ReceiverError("片段 SHA256 不匹配: {}".format(name))
            installed = _install_verified(temp, target, size, digest)
            say("片段大小与 SHA256 通过 / PASS: {}".format(name))
            return installed
        except (OSError, HTTPException, ReceiverError) as exc:
            last_error = exc
            if isinstance(exc, HTTPError) and exc.code == 416 and temp.exists():
                _preserve(temp, "range-rejected")
            say("尝试 {} 失败: {}".format(attempt, exc))
            if attempt < MAX_ATTEMPTS:
                time.sleep(RETRY_DELAY_SECONDS * attempt)
    raise ReceiverError("下载已尝试 3 次，稍后重运行同一命令可继续。{}: {}".format(name, last_error))


def assemble_archive(archive, downloads, archives):
    validate_manifest({"archives": [archive]})
    downloads, archives = Path(downloads), Path(archives)
    archives.mkdir(parents=True, exist_ok=True)
    name = archive["filename"]
    paths = []
    for part in archive["parts"]:
        path = downloads / part["name"]
        if not file_matches(path, part["bytes"], part["sha256"]):
            raise ReceiverError("缺片、大小错误或 SHA256 错误；未生成 ZIP: {}".format(path))
        paths.append(path)
    target, temp = archives / name, archives / (name + ".assembling.part")
    if file_matches(target, archive["bytes"], archive["sha256"]):
        say("ZIP 已验证，保持原文件 / PASS cached archive: {}".format(name))
        return target
    if temp.exists() or temp.is_symlink():
        _preserve(temp, "previous")
    say("合并并校验 / assembling: {}  ({} parts)".format(name, len(paths)))
    digest, count = hashlib.sha256(), 0
    with temp.open("xb") as output:
        for path in paths:
            with path.open("rb") as source:
                for block in iter(lambda: source.read(CHUNK_BYTES), b""):
                    output.write(block)
                    digest.update(block)
                    count += len(block)
        output.flush()
        os.fsync(output.fileno())
    if (count != archive["bytes"] or digest.hexdigest() != archive["sha256"].lower()
            or not file_matches(temp, archive["bytes"], archive["sha256"])):
        _preserve(temp)
        raise ReceiverError("完整 ZIP 大小或 SHA256 校验失败，未生成正式 ZIP: {}".format(name))
    installed = _install_verified(temp, target, archive["bytes"], archive["sha256"])
    say("完整 ZIP 大小与 SHA256 通过 / PASS archive: {}".format(name))
    return installed


def _read_manifest(path):
    if path.stat().st_size > MANIFEST_LIMIT:
        raise ReceiverError("清单超过 8 MiB 上限")
    try:
        with path.open("r", encoding="utf-8-sig") as stream:
            return validate_manifest(json.load(stream))
    except (ValueError, UnicodeError) as exc:
        raise ReceiverError("清单不是有效 UTF-8 JSON: {}".format(exc)) from exc


def _fetch_manifest(downloads):
    target, temp = downloads / MANIFEST_NAME, downloads / (MANIFEST_NAME + ".part")
    if temp.exists() or temp.is_symlink():
        _preserve(temp, "previous")
    for attempt in range(1, MAX_ATTEMPTS + 1):
        try:
            say("获取固定 Release 清单 / manifest {}/3".format(attempt))
            with _open_url(_request(DOWNLOAD_PREFIX + MANIFEST_NAME)) as response:
                if response.getcode() != 200:
                    raise ReceiverError("清单下载必须返回 HTTP 200")
                data = response.read(MANIFEST_LIMIT + 1)
                if len(data) > MANIFEST_LIMIT:
                    raise ReceiverError("清单超过 8 MiB 上限")
            with temp.open("wb") as stream:
                stream.write(data)
            manifest = _read_manifest(temp)
            if target.exists() or target.is_symlink():
                _preserve(target, "previous")
            temp.rename(target)
            return manifest
        except (OSError, HTTPException, ReceiverError) as exc:
            say("清单获取失败 {}: {}".format(attempt, exc))
            if attempt == MAX_ATTEMPTS:
                raise ReceiverError("无法获取公开 Release 清单；保留 .part。{}".format(exc)) from exc
            if temp.exists():
                _preserve(temp, "bad")
            time.sleep(RETRY_DELAY_SECONDS * attempt)


def main(argv=None):
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="backslashreplace")
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--download", action="store_true", help="下载缺失或错误片段，然后合并校验")
    mode.add_argument("--assemble-only", action="store_true", help="仅使用本地 downloads，不发起网络请求")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parent / "received_assets", help="输出目录，内含 downloads 和 archives")
    parser.add_argument("--manifest", type=Path, help="本地清单；默认脚本同目录 TRANSPORT_MANIFEST.json")
    args = parser.parse_args(argv)
    output = args.output.expanduser().resolve()
    downloads, archives = output / "downloads", output / "archives"
    downloads.mkdir(parents=True, exist_ok=True)
    archives.mkdir(parents=True, exist_ok=True)
    local = args.manifest or (Path(__file__).resolve().parent / MANIFEST_NAME)
    if local.exists():
        manifest = _read_manifest(local)
        say("使用本地清单: {}".format(local))
    elif args.manifest:
        raise ReceiverError("指定清单不存在: {}".format(local))
    elif (downloads / MANIFEST_NAME).exists():
        manifest = _read_manifest(downloads / MANIFEST_NAME)
        say("使用下载缓存清单: {}".format(downloads / MANIFEST_NAME))
    elif args.download:
        manifest = _fetch_manifest(downloads)
    else:
        raise ReceiverError("缺少 TRANSPORT_MANIFEST.json；请放在脚本同目录或使用 --download")
    for index, archive in enumerate(manifest["archives"], 1):
        say("\n[{}/{}] {}".format(index, len(manifest["archives"]), archive["filename"]))
        if args.download:
            for part in archive["parts"]:
                download_part(part, downloads)
        assemble_archive(archive, downloads, archives)
    say("\n全部完成 / ALL PASS: {} ZIP，位于 {}".format(len(manifest["archives"]), archives))
    say("每片及每个完整 ZIP 的大小和 SHA256 均已通过。未执行解压。")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ReceiverError, OSError) as error:
        say("\n失败 / FAILED: {}".format(error))
        sys.exit(1)
    except KeyboardInterrupt:
        say("\n已中断；保留已有文件和 .part，重新运行同一命令可继续。")
        sys.exit(130)
