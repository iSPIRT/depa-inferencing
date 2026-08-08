"""REST transport (Azure).

Azure offer frontends front the gRPC BFE with an Envoy proxy that transcodes a
JSON ``{requestCiphertext, keyId}`` body into the ``BuyerFrontEnd.GetBids`` gRPC
call. We therefore POST the JSON body emitted by the crypto library verbatim and
read ``responseCiphertext`` back out.
"""

from __future__ import annotations

import time
from typing import Optional

import requests
import urllib3

from ..config import SecureInvokeConfig
from ..crypto import EncryptResult
from ..errors import TransportError
from ..urls import join_url
from .base import Transport

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

_RESPONSE_CIPHERTEXT_KEYS = ("responseCiphertext", "response_ciphertext")


class RestTransport(Transport):
    def __init__(self, config: SecureInvokeConfig):
        self.config = config
        self.url = join_url(config.offer_host, config.offer_endpoint, default_scheme="http")
        self.session = requests.Session()
        self.session.headers.update(
            {"Content-Type": "application/json", "Accept": "application/json"}
        )
        if config.headers:
            self.session.headers.update(config.headers)
        self._configure_tls()

    def _configure_tls(self) -> None:
        cfg = self.config
        if cfg.insecure:
            self.session.verify = False
        elif cfg.ca_cert:
            self.session.verify = cfg.ca_cert
        else:
            self.session.verify = True
        if cfg.client_cert and cfg.client_key:
            self.session.cert = (cfg.client_cert, cfg.client_key)
        elif cfg.client_cert:
            self.session.cert = cfg.client_cert

    def _log(self, msg: str) -> None:
        if self.config.verbose:
            print(f"[rest] {msg}")

    def send(self, encrypted: EncryptResult) -> str:
        headers = {"x-key-id": str(encrypted.key_id)}
        if self.config.client_ip:
            headers["x-bna-client-ip"] = self.config.client_ip

        attempts = max(1, self.config.retries)
        last_exc: Optional[Exception] = None
        for attempt in range(1, attempts + 1):
            try:
                self._log(f"POST {self.url} (attempt {attempt}/{attempts})")
                resp = self.session.post(
                    self.url,
                    data=encrypted.payload,
                    headers=headers,
                    timeout=self.config.timeout,
                )
                resp.raise_for_status()
                data = resp.json()
                ciphertext = _extract_ciphertext(data)
                if ciphertext is None:
                    raise TransportError(
                        f"no response ciphertext in offer response (keys: {list(data)})"
                    )
                return ciphertext
            except TransportError:
                raise
            except (requests.exceptions.RequestException, ValueError) as exc:
                last_exc = exc
                self._log(f"attempt {attempt} failed: {exc}")
                if attempt < attempts:
                    time.sleep(self.config.retry_delay)

        raise TransportError(f"REST request to {self.url} failed: {last_exc}")

    def close(self) -> None:
        self.session.close()


def _extract_ciphertext(data) -> Optional[str]:
    if not isinstance(data, dict):
        return None
    for key in _RESPONSE_CIPHERTEXT_KEYS:
        if data.get(key):
            return str(data[key])
    return None
