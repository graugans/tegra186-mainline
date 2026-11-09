#!/usr/bin/env python3
"""rootfs-helper: the only writer of the NFS rootfs.

Runs as root in the lab Compose stack and offers a few fixed actions over
HTTP on localhost, so the unprivileged dev container never touches the NFS
root directly:

  GET  /status           rootfs and kernel-out state
  POST /rootfs/reset     wipe NFS_ROOT and unpack the Yocto rootfs tarball
  POST /modules/install  copy kernel modules from KERNEL_OUT into the rootfs

Requests take no parameters; all paths are fixed by the environment.
"""
import json
import os
import shutil
import subprocess
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NFS_ROOT = os.environ.get("NFS_ROOT", "/nfsroot")
ROOTFS_TARBALL = os.environ.get(
    "ROOTFS_TARBALL",
    "/work/yocto/build/tmp/deploy/images/genericarm64/"
    "core-image-minimal-genericarm64.rootfs.tar.zst",
)
KERNEL_OUT = os.environ.get("KERNEL_OUT", "/work/kernel-out")
LISTEN = os.environ.get("HELPER_LISTEN", "127.0.0.1:8091")
MARKER = ".rootfs-helper"

lock = threading.Lock()


class ActionError(Exception):
    pass


def run(cmd, log):
    log.append("$ " + " ".join(cmd))
    p = subprocess.run(cmd, capture_output=True, text=True)
    out = (p.stdout + p.stderr).strip()
    if out:
        log.append(out)
    if p.returncode:
        raise ActionError(f"{cmd[0]} exited with {p.returncode}")


def check_root():
    root = os.path.realpath(NFS_ROOT)
    if root == "/" or not os.path.isdir(root):
        raise ActionError(f"refusing to use NFS_ROOT={NFS_ROOT!r}")
    return root


def inside_root(root, rel):
    """Resolve rel inside root, following symlinks *relative to root*."""
    path = root
    for part in rel.strip("/").split("/"):
        cand = os.path.join(path, part)
        hops = 0
        while os.path.islink(cand):
            hops += 1
            if hops > 16:
                raise ActionError(f"symlink loop at {cand}")
            target = os.readlink(cand)
            base = root if target.startswith("/") else os.path.dirname(cand)
            cand = os.path.normpath(os.path.join(base, target.lstrip("/")))
        if os.path.commonpath([root, cand]) != root:
            raise ActionError(f"{rel} escapes the rootfs")
        path = cand
    return path


def rootfs_reset(log):
    root = check_root()
    if not os.path.isfile(ROOTFS_TARBALL):
        raise ActionError(f"rootfs tarball not found: {ROOTFS_TARBALL}")
    tarball = os.path.realpath(ROOTFS_TARBALL)
    log.append(f"wiping {root}")
    run(["find", root, "-xdev", "-mindepth", "1", "-delete"], log)
    log.append(f"unpacking {tarball}")
    run(["tar", "--zstd", "-xpf", tarball, "-C", root,
         "--numeric-owner", "--xattrs", "--xattrs-include=*"], log)
    with open(os.path.join(root, MARKER), "w") as f:
        f.write(os.path.basename(tarball) + "\n")


def modules_install(log):
    root = check_root()
    src_base = os.path.join(KERNEL_OUT, "modules", "lib", "modules")
    if not os.path.isdir(src_base):
        raise ActionError(f"no modules in {src_base}")
    releases = sorted(os.listdir(src_base))
    if len(releases) != 1:
        raise ActionError(f"expected one kernel release in {src_base}, got {releases}")
    if not os.path.exists(os.path.join(root, MARKER)):
        raise ActionError("rootfs not initialised, run /rootfs/reset first")
    dest_base = inside_root(root, "lib/modules")
    os.makedirs(dest_base, exist_ok=True)
    rel = releases[0]
    # build/source point into the dev container's build tree; useless on target.
    run(["rsync", "-a", "--delete", "--chown=0:0",
         "--exclude=/build", "--exclude=/source",
         os.path.join(src_base, rel) + "/", os.path.join(dest_base, rel) + "/"], log)
    log.append(f"installed modules for {rel}")


def status():
    root = os.path.realpath(NFS_ROOT)
    marker = os.path.join(root, MARKER)
    version = os.path.join(KERNEL_OUT, "VERSION")
    st = {"nfs_root": root, "rootfs": None, "kernel_out": None,
          "free_bytes": shutil.disk_usage(root).free if os.path.isdir(root) else None}
    if os.path.isfile(marker):
        st["rootfs"] = open(marker).read().strip()
    if os.path.isfile(version):
        st["kernel_out"] = dict(
            line.split("=", 1) for line in open(version).read().split("\n") if "=" in line)
    return st


ACTIONS = {"/rootfs/reset": rootfs_reset, "/modules/install": modules_install}


class Handler(BaseHTTPRequestHandler):
    def reply(self, code, body):
        data = (json.dumps(body, indent=2) + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path != "/status":
            return self.reply(404, {"error": "unknown path"})
        self.reply(200, status())

    def do_POST(self):
        action = ACTIONS.get(self.path)
        if action is None:
            return self.reply(404, {"error": "unknown action"})
        if not lock.acquire(blocking=False):
            return self.reply(409, {"error": "another action is running"})
        log = []
        try:
            action(log)
            self.reply(200, {"ok": True, "log": log})
        except Exception as e:  # report every failure to the caller
            self.reply(500, {"ok": False, "error": str(e), "log": log})
        finally:
            lock.release()


def main():
    host, port = LISTEN.rsplit(":", 1)
    print(f"rootfs-helper on {host}:{port}, NFS_ROOT={NFS_ROOT}", flush=True)
    ThreadingHTTPServer((host, int(port)), Handler).serve_forever()


if __name__ == "__main__":
    main()
