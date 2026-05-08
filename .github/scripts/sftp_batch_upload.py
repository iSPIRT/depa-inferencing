#!/usr/bin/env python3
"""Run OpenSSH `sftp -b batchfile` while answering host-key and password prompts.

Many gateways use keyboard-interactive and weird auth-method ordering. Runner ssh-agent sockets
often offer unrelated keys unless we isolate the identity file."""

from __future__ import annotations

import argparse
import os
import sys


def read_password_bytes(path: str) -> bytes:
    with open(path, "rb") as f:
        data = f.read().replace(b"\r", b"")
    while data.endswith(b"\n"):
        data = data[:-1]
    return data


def run_one_attempt(
    *,
    host: str,
    port: int,
    user: str,
    identity: str,
    batch: str,
    preferred: str,
    password: bytes,
    debug: bool,
) -> int:
    """Return 0 OK; 3 timeout; 4 too many prompts; 5 denied/closed in stream; else sftp exit code."""
    import pexpect  # type: ignore[import-not-found]

    target = f"{user}@{host}"
    cmd: list[str] = ["sftp"]
    # Match `ssh -vvv` / high LogLevel for auth-method tracing (enable via SFTP_PEXPECT_DEBUG).
    if debug:
        cmd.extend(["-vvv", "-o", "LogLevel=DEBUG3"])
    cmd.extend(
        [
        "-P",
        str(port),
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-o",
        f"PreferredAuthentications={preferred}",
        "-o",
        "IdentitiesOnly=yes",
        "-o",
        "PubkeyAuthentication=yes",
        "-o",
        "KbdInteractiveAuthentication=yes",
        "-o",
        "PasswordAuthentication=yes",
        "-o",
        "NumberOfPasswordPrompts=8",
        "-i",
        identity,
        "-b",
        batch,
        target,
        ]
    )

    env = os.environ.copy()
    env.pop("SSH_AUTH_SOCK", None)
    env.pop("SSH_AGENT_PID", None)

    child = pexpect.spawn(cmd[0], cmd[1:], timeout=900, encoding=None, env=env)
    if debug:
        child.logfile_read = sys.stderr.buffer
        sys.stderr.flush()

    print(f"Sftp auth try: PreferredAuthentications={preferred}", file=sys.stderr)

    host_key = rb"(?i)are you sure you want to continue connecting"
    pat_password = rb"(?i)(password|passcode|\bpin\b|otp|token|shared secret|authenticate|please enter|\(password\))"
    passphrase = rb"(?i)passphrase for key"
    denied = rb"(?i)Permission denied"
    closed = rb"(?i)Connection closed"

    sent_pw_rounds = 0
    tried_empty_passphrase = False

    def dump_tail() -> None:
        buf = (child.before or b"") + (child.after or b"")
        print(buf.decode(errors="replace")[-4000:].strip(), file=sys.stderr)

    try:
        while True:
            try:
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
            except pexpect.TIMEOUT:  # type: ignore[attr-defined]
                print("SFTP pexpect timed out. Recent output:", file=sys.stderr)
                dump_tail()
                child.close(force=True)
                return 3

            if debug and child.before:
                sys.stderr.buffer.write(child.before[-1200:])
                sys.stderr.buffer.flush()

            if i == 0:
                child.sendline(b"yes")
            elif i == 1:
                child.sendline(password)
                sent_pw_rounds += 1
                if sent_pw_rounds > 12:
                    print("Giving up — too many password-style prompts.", file=sys.stderr)
                    child.close(force=True)
                    return 4
            elif i == 2:
                if not tried_empty_passphrase:
                    child.sendline(b"")
                    tried_empty_passphrase = True
                else:
                    child.sendline(password)
            elif i in (3, 4):
                dump_tail()
                child.close(force=True)
                return 5
            elif i == 5:
                child.close(force=False)
                es = child.exitstatus
                if child.signalstatus is not None:
                    return 130
                if es is None:
                    return 0
                return int(es) if isinstance(es, int) else 1
    finally:
        try:
            if child.isalive():
                child.close(force=True)
        except Exception:
            pass


def main() -> int:
    try:
        import pexpect  # noqa: F401
    except ImportError:
        print(
            "Missing dependency pexpect — apt install python3-pexpect or pip install pexpect",
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

    auth_orders = (
        "publickey,keyboard-interactive,password",
        "keyboard-interactive,password,publickey",
        "password,keyboard-interactive,publickey",
    )

    last = 99
    for pref in auth_orders:
        last = run_one_attempt(
            host=args.host.strip(),
            port=args.port,
            user=args.user.strip(),
            identity=args.identity,
            batch=args.batch,
            preferred=pref,
            password=password,
            debug=debug,
        )
        if last == 0:
            return 0
        if last == 4:
            return last
        print(
            f"SFTP PreferredAuthentications={pref} exited {last}; trying next order…",
            file=sys.stderr,
        )

    return last


if __name__ == "__main__":
    sys.exit(main())
