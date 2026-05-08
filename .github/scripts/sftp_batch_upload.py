#!/usr/bin/env python3
"""Run OpenSSH `sftp -b batchfile` while answering host-key and password prompts.

Many SFTP gateways use publickey followed by keyboard-interactive; ssh/sshpass miss
those prompts inconsistently and report `Permission denied (password)`."""

from __future__ import annotations

import argparse
import os
import sys


def read_password_bytes(path: str) -> bytes:
    with open(path, "rb") as f:
        data = f.read().replace(b"\r", b"")
    # Allow trailing LF from editors; passwords normally do not intentionally end with LF.
    while data.endswith(b"\n"):
        data = data[:-1]
    return data


def main() -> int:
    try:
        import pexpect  # type: ignore[import-not-found]
    except ImportError:
        print(
            "Missing dependency pexpect — install with: python3 -m pip install pexpect",
            file=sys.stderr,
        )
        return 127

    ap = argparse.ArgumentParser()
    ap.add_argument("--host", required=True)
    ap.add_argument("--port", type=int, default=22)
    ap.add_argument("--user", required=True)
    ap.add_argument("--identity", required=True, help="Path to OpenSSH private key")
    ap.add_argument("--password-file", required=True)
    ap.add_argument("--batch", required=True, help="sftp batch commands file")
    args = ap.parse_args()

    password = read_password_bytes(args.password_file)
    debug = os.environ.get("SFTP_PEXPECT_DEBUG", "").lower() in ("1", "true", "yes")

    cmd = [
        "sftp",
        "-P",
        str(args.port),
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-o",
        "PreferredAuthentications=publickey,keyboard-interactive,password",
        "-o",
        "PubkeyAuthentication=yes",
        "-o",
        "KbdInteractiveAuthentication=yes",
        "-o",
        "PasswordAuthentication=yes",
        "-o",
        "NumberOfPasswordPrompts=5",
        "-i",
        args.identity,
        "-b",
        args.batch,
        f"{args.user}@{args.host}",
    ]

    child = pexpect.spawn(cmd[0], cmd[1:], timeout=900, encoding=None)
    if debug:
        child.logfile_read = sys.stderr.buffer

    host_key = rb"(?i)are you sure you want to continue connecting"
    # Broader than "Password:" — some gateways use keyboard-interactive with odd labels.
    pat_password = rb"(?i)(password|passcode|\bpin\b|otp|token|shared secret|authenticate)"
    passphrase = rb"(?i)passphrase for key"
    denied = rb"(?i)Permission denied"
    closed = rb"(?i)Connection closed"

    sent_pw_rounds = 0
    tried_empty_passphrase = False

    try:
        while True:
            i = child.expect(
                [
                    host_key,
                    pat_password,
                    passphrase,
                    denied,
                    closed,
                    pexpect.EOF,  # type: ignore[attr-defined]
                ],
                timeout=600,
            )
            if debug and child.before:
                sys.stderr.buffer.write(child.before[-500:])
                sys.stderr.buffer.flush()

            if i == 0:
                child.sendline(b"yes")
            elif i == 1:
                child.sendline(password)
                sent_pw_rounds += 1
                if sent_pw_rounds > 10:
                    print("Giving up — too many password-style prompts.", file=sys.stderr)
                    return 4
            elif i == 2:
                # CI keys are usually passphrase-less; retry with password once.
                if not tried_empty_passphrase:
                    child.sendline(b"")
                    tried_empty_passphrase = True
                else:
                    child.sendline(password)
            elif i in (3, 4):
                combined = (child.before or b"") + (child.after or b"")
                tail = combined.decode(errors="replace")[-2000:]
                print(tail.strip(), file=sys.stderr)
                return 5
            elif i == 5:
                break
    except pexpect.TIMEOUT:  # type: ignore[attr-defined]
        tail = ""
        try:
            if child.before:
                tail = child.before.decode(errors="replace")[-2500:]
        except Exception:
            tail = repr(child.before[-500:] if child.before else b"")
        print("SFTP pexpect timed out. Recent output:", file=sys.stderr)
        print(tail, file=sys.stderr)
        return 3

    child.close(force=False)
    es = child.exitstatus if child.exitstatus is not None else 0
    return int(es) if isinstance(es, int) else 0


if __name__ == "__main__":
    sys.exit(main())
