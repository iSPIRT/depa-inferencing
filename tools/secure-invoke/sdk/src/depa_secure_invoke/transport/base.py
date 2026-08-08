"""Transport interface.

A transport takes the output of :meth:`SecureInvokeCrypto.encrypt` and ships it
to the offer host, returning the *base64* response ciphertext that can be fed
straight back into :meth:`SecureInvokeCrypto.decrypt`.
"""

from __future__ import annotations

import abc

from ..crypto import EncryptResult


class Transport(abc.ABC):
    @abc.abstractmethod
    def send(self, encrypted: EncryptResult) -> str:
        """Send ``encrypted`` and return the response ciphertext as base64.

        Raises:
            TransportError: on any network/protocol failure.
        """

    def close(self) -> None:  # optional resource cleanup
        pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
