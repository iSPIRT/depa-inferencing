"""gRPC transport (GCP).

GCP BuyerFrontEnd deployments have no Envoy/REST front door, so we speak gRPC
directly to ``BuyerFrontEnd.GetBids``. The crypto library still produces the same
ciphertext; here we base64-decode it into the ``request_ciphertext`` bytes field
and base64-encode the response bytes on the way back.

Security model:
* ``insecure=True``  -> plaintext channel (local / testing only).
* otherwise          -> TLS channel. ``ca_cert`` overrides the root store and
  ``client_cert``/``client_key`` enable mTLS.
"""

from __future__ import annotations

import base64
import time
from typing import List, Optional, Tuple

import grpc

from ..config import SecureInvokeConfig
from ..crypto import EncryptResult
from ..errors import TransportError
from ..proto import pb2, pb2_grpc
from .base import Transport


class GrpcTransport(Transport):
    def __init__(self, config: SecureInvokeConfig):
        self.config = config
        self.target = _grpc_target(config.offer_host)
        self.channel = self._build_channel()
        self.stub = pb2_grpc.BuyerFrontEndStub(self.channel)

    def _log(self, msg: str) -> None:
        if self.config.verbose:
            print(f"[grpc] {msg}")

    def _build_channel(self) -> grpc.Channel:
        cfg = self.config
        if cfg.insecure:
            self._log(f"insecure (plaintext) channel to {self.target}")
            return grpc.insecure_channel(self.target)

        root_certs = _read_bytes(cfg.ca_cert)
        private_key = _read_bytes(cfg.client_key)
        cert_chain = _read_bytes(cfg.client_cert)
        creds = grpc.ssl_channel_credentials(
            root_certificates=root_certs,
            private_key=private_key,
            certificate_chain=cert_chain,
        )
        self._log(f"TLS channel to {self.target}")
        return grpc.secure_channel(self.target, creds)

    def _metadata(self, key_id: str) -> List[Tuple[str, str]]:
        metadata: List[Tuple[str, str]] = [("x-key-id", str(key_id))]
        if self.config.client_ip:
            metadata.append(("x-bna-client-ip", self.config.client_ip))
        for name, value in (self.config.headers or {}).items():
            metadata.append((name.lower(), value))
        return metadata

    def send(self, encrypted: EncryptResult) -> str:
        request = pb2.GetBidsRequest(
            request_ciphertext=encrypted.ciphertext_bytes,
            key_id=str(encrypted.key_id),
        )
        metadata = self._metadata(encrypted.key_id)

        attempts = max(1, self.config.retries)
        last_exc: Optional[Exception] = None
        for attempt in range(1, attempts + 1):
            try:
                self._log(
                    f"GetBids -> {self.target} (attempt {attempt}/{attempts})"
                )
                response = self.stub.GetBids(
                    request, timeout=self.config.timeout, metadata=metadata
                )
                if not response.response_ciphertext:
                    raise TransportError("empty response_ciphertext from BFE")
                return base64.b64encode(response.response_ciphertext).decode("ascii")
            except TransportError:
                raise
            except grpc.RpcError as exc:
                last_exc = exc
                code = exc.code() if hasattr(exc, "code") else "?"
                detail = exc.details() if hasattr(exc, "details") else str(exc)
                self._log(f"attempt {attempt} failed: {code} {detail}")
                if attempt < attempts:
                    time.sleep(self.config.retry_delay)

        raise TransportError(f"gRPC GetBids to {self.target} failed: {last_exc}")

    def close(self) -> None:
        self.channel.close()


def _grpc_target(host: str) -> str:
    """Reduce a possibly-URL host to a gRPC ``host:port`` target."""
    target = (host or "").strip()
    for scheme in ("https://", "http://", "dns:///"):
        if target.startswith(scheme):
            target = target[len(scheme):]
            break
    # Drop any path component (gRPC targets are host:port only).
    target = target.split("/", 1)[0]
    if not target:
        raise TransportError("offer_host is required for gRPC transport")
    return target


def _read_bytes(path: Optional[str]) -> Optional[bytes]:
    if not path:
        return None
    with open(path, "rb") as handle:
        return handle.read()
