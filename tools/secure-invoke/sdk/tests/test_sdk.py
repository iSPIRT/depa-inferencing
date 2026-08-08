"""Unit tests for the DEPA secure-invoke SDK (no network required)."""

import io
import json
import os
import time
from contextlib import redirect_stdout

import pytest

from depa_secure_invoke import SecureInvokeConfig
from depa_secure_invoke.cache import FileKeyCache, MemoryKeyCache
from depa_secure_invoke.client import _build_key_cache
from depa_secure_invoke.config import DEFAULT_KMS_KEYS_ENDPOINT
from depa_secure_invoke.crypto import _parse_payload, get_default_crypto
from depa_secure_invoke.errors import ConfigError, CryptoError, TransportError
from depa_secure_invoke.keys import PublicKey
from depa_secure_invoke.kms import KMSClient
from depa_secure_invoke.native import _extract_json, resolve_native_bin
from depa_secure_invoke.requests_io import load_batch_from_file, load_request
from depa_secure_invoke.transport.grpc_ import _grpc_target
from depa_secure_invoke.transport.rest import _extract_ciphertext
from depa_secure_invoke.urls import join_url


# --- URL joins (the headline bug fix) ---------------------------------------

def test_join_preserves_path_prefix():
    assert join_url("https://kms.example.com", "/app/listpubkeys") == (
        "https://kms.example.com/app/listpubkeys"
    )
    assert join_url("https://gw.example.com/tenant-a", "/app/listpubkeys") == (
        "https://gw.example.com/tenant-a/app/listpubkeys"
    )


def test_join_adds_scheme_and_trims_slashes():
    assert join_url("kms.example.com/", "app/listpubkeys/") == (
        "https://kms.example.com/app/listpubkeys/"
    )


def test_join_empty_endpoint_returns_host():
    assert join_url("https://kms.example.com/app/listpubkeys", "") == (
        "https://kms.example.com/app/listpubkeys"
    )


def test_default_keys_endpoint_is_app_prefixed():
    assert DEFAULT_KMS_KEYS_ENDPOINT == "/app/listpubkeys"


# --- config validation ------------------------------------------------------

def test_config_requires_hosts():
    with pytest.raises(ConfigError):
        SecureInvokeConfig(offer_host="h:1").validate()
    with pytest.raises(ConfigError):
        SecureInvokeConfig(kms_host="https://k").validate()


def test_config_rejects_half_mtls():
    cfg = SecureInvokeConfig(kms_host="https://k", offer_host="h:1", client_cert="c")
    with pytest.raises(ConfigError):
        cfg.validate()


def test_config_rejects_bad_protocol():
    cfg = SecureInvokeConfig(kms_host="https://k", offer_host="h:1", protocol="soap")
    with pytest.raises(ConfigError):
        cfg.validate()


def test_config_rejects_bad_backend():
    cfg = SecureInvokeConfig(kms_host="https://k", offer_host="h:1", backend="nope")
    with pytest.raises(ConfigError):
        cfg.validate()


def test_config_rejects_negative_cache_ttl():
    cfg = SecureInvokeConfig(kms_host="https://k", offer_host="h:1", cache_ttl=-1)
    with pytest.raises(ConfigError):
        cfg.validate()


# --- public key caching -----------------------------------------------------

def _keys():
    return [PublicKey(key_id="11", public_key="AAAA")]


def test_memory_cache_get_set_and_ttl_zero():
    c = MemoryKeyCache()
    assert c.get("u") is None
    c.set("u", _keys(), ttl=60)
    assert c.get("u") == _keys()
    # ttl <= 0 must not store.
    c.set("v", _keys(), ttl=0)
    assert c.get("v") is None


def test_memory_cache_expires(monkeypatch):
    import depa_secure_invoke.cache as cache_mod

    now = [1000.0]
    monkeypatch.setattr(cache_mod.time, "monotonic", lambda: now[0])
    c = MemoryKeyCache()
    c.set("u", _keys(), ttl=10)
    now[0] = 1009.0
    assert c.get("u") == _keys()
    now[0] = 1011.0
    assert c.get("u") is None


def test_file_cache_persists_across_instances(tmp_path):
    path = str(tmp_path / "cache.json")
    FileKeyCache(path).set("u", _keys(), ttl=60)
    # A fresh instance (i.e. a separate process) sees the cached value.
    assert FileKeyCache(path).get("u") == _keys()


def test_file_cache_expired_is_ignored(tmp_path, monkeypatch):
    import depa_secure_invoke.cache as cache_mod

    path = str(tmp_path / "cache.json")
    monkeypatch.setattr(cache_mod.time, "time", lambda: 1000.0)
    FileKeyCache(path).set("u", _keys(), ttl=10)
    monkeypatch.setattr(cache_mod.time, "time", lambda: 1020.0)
    assert FileKeyCache(path).get("u") is None


def test_build_key_cache_selection(tmp_path):
    base = dict(kms_host="https://k", offer_host="h:1")
    assert _build_key_cache(SecureInvokeConfig(**base)) is None
    assert isinstance(
        _build_key_cache(SecureInvokeConfig(cache_keys=True, **base)), MemoryKeyCache
    )
    file_cfg = SecureInvokeConfig(cache_file=str(tmp_path / "c.json"), **base)
    assert isinstance(_build_key_cache(file_cfg), FileKeyCache)


# --- KMS TTL resolution from response headers -------------------------------

class _Resp:
    def __init__(self, headers):
        self.headers = headers


def _kms(**kw):
    return KMSClient("https://k", cache_ttl=900, **kw)


def test_resolve_ttl_honors_max_age():
    assert _kms()._resolve_ttl(_Resp({"Cache-Control": "public, max-age=120"})) == 120


def test_resolve_ttl_no_store_disables_caching():
    assert _kms()._resolve_ttl(_Resp({"Cache-Control": "no-store"})) is None


def test_resolve_ttl_falls_back_when_no_headers():
    assert _kms()._resolve_ttl(_Resp({})) == 900


def test_resolve_ttl_ignore_server_uses_fallback():
    kms = _kms(respect_server_cache=False)
    assert kms._resolve_ttl(_Resp({"Cache-Control": "max-age=5"})) == 900


def test_resolve_ttl_expires_header():
    from email.utils import formatdate

    future = _kms()._resolve_ttl(
        _Resp({"Expires": formatdate(time.time() + 100, usegmt=True)})
    )
    assert 80 <= future <= 100


# --- backend selection ------------------------------------------------------

def test_effective_backend_auto_maps_by_protocol():
    base = dict(kms_host="https://k", offer_host="h:1")
    assert SecureInvokeConfig(protocol="rest", **base).effective_backend() == "python"
    assert SecureInvokeConfig(protocol="grpc", **base).effective_backend() == "native"


def test_effective_backend_explicit_wins():
    cfg = SecureInvokeConfig(
        kms_host="https://k", offer_host="h:1", protocol="grpc", backend="python"
    )
    assert cfg.effective_backend() == "python"


# --- native backend helpers -------------------------------------------------

def test_native_extract_json_direct_and_embedded():
    assert _extract_json('{"bids": [1, 2]}') == {"bids": [1, 2]}
    # Log lines before the payload must be tolerated.
    noisy = 'I0708 log line\nWARNING blah\n{"bids": []}'
    assert _extract_json(noisy) == {"bids": []}


def test_native_extract_json_empty_raises():
    with pytest.raises(TransportError):
        _extract_json("   ")


def test_resolve_native_bin_env_override(tmp_path, monkeypatch):
    fake = tmp_path / "invoke"
    fake.write_text("#!/bin/sh\n")
    fake.chmod(0o755)
    monkeypatch.setenv("SECURE_INVOKE_NATIVE_BIN", str(fake))
    assert resolve_native_bin() == str(fake)


def test_resolve_native_bin_missing(monkeypatch):
    monkeypatch.delenv("SECURE_INVOKE_NATIVE_BIN", raising=False)
    # An explicit, non-existent path should not resolve; if nothing else is
    # available this raises ConfigError.
    monkeypatch.setattr("shutil.which", lambda _name: None)
    import depa_secure_invoke.native as native_mod

    monkeypatch.setattr(native_mod, "_BUNDLED_BIN", "/nonexistent/invoke")
    with pytest.raises(ConfigError):
        resolve_native_bin("/definitely/not/here")


# --- request loading --------------------------------------------------------

def test_load_request_inline_dict_and_unwrap():
    assert load_request({"a": 1}) == {"a": 1}
    assert load_request({"id": 5, "request": {"a": 1}}) == {"a": 1}


def test_load_request_inline_json_string():
    assert load_request('{"a": 1}') == {"a": 1}


def test_load_request_rejects_both_and_neither():
    with pytest.raises(ConfigError):
        load_request({"a": 1}, "file.json")
    with pytest.raises(ConfigError):
        load_request()


def test_load_batch_jsonl(tmp_path):
    p = tmp_path / "batch.jsonl"
    p.write_text('{"id":1,"request":{"a":1}}\n\n{"a":2}\n')
    rows = load_batch_from_file(str(p))
    assert rows == [{"a": 1}, {"a": 2}]


# --- payload / ciphertext parsing ------------------------------------------

def test_parse_payload_camel_case():
    payload = json.dumps({"requestCiphertext": "Y2lwaGVy", "keyId": "42"})
    ciphertext, key_id = _parse_payload(payload)
    assert ciphertext == "Y2lwaGVy"
    assert key_id == "42"


def test_parse_payload_missing_ciphertext():
    with pytest.raises(CryptoError):
        _parse_payload(json.dumps({"keyId": "42"}))


def test_extract_response_ciphertext():
    assert _extract_ciphertext({"responseCiphertext": "abc"}) == "abc"
    assert _extract_ciphertext({"response_ciphertext": "abc"}) == "abc"
    assert _extract_ciphertext({"other": 1}) is None


# --- gRPC target normalization ---------------------------------------------

def test_grpc_target_strips_scheme_and_path():
    assert _grpc_target("https://bfe.example.com:443/v1/getbids") == "bfe.example.com:443"
    assert _grpc_target("bfe.example.com:443") == "bfe.example.com:443"
    assert _grpc_target("dns:///bfe.example.com:443") == "bfe.example.com:443"


# --- crypto library loads + stdout suppression ------------------------------

def test_crypto_loads_and_reports_version():
    crypto = get_default_crypto()
    assert crypto.version()  # non-empty


def test_native_stdout_is_suppressed_by_default():
    """Encrypt must not leak the C library's printf debug lines to stdout."""
    crypto = get_default_crypto()
    # A deterministic 32-byte base64 public key + numeric key id.
    pub = "ZwxRFBH5ky8dMNrJSx9Q3EBiL/DXUsZw0ux85ZQBT2o="
    buf = io.StringIO()
    with redirect_stdout(buf):
        # Also redirect at fd-level check: print a sentinel that SHOULD appear.
        print("SENTINEL_BEFORE")
        try:
            crypto.encrypt({"seller": "x", "publisher_name": "x"}, pub, "89", quiet=True)
        except CryptoError:
            pass  # encryption may fail on the fake key; we only assert on stdout
    out = buf.getvalue()
    assert "SENTINEL_BEFORE" in out
    assert "Returning from encrypt" not in out
    assert "Using key_id" not in out
