"""The public-key value type shared by the KMS client and the cache layer.

Kept in its own module so :mod:`depa_secure_invoke.kms` and
:mod:`depa_secure_invoke.cache` can both use it without importing each other.
"""

from __future__ import annotations


class PublicKey(dict):
    """A normalized KMS public key: ``{"key_id": str, "public_key": str}``."""

    @property
    def key_id(self) -> str:
        return self["key_id"]

    @property
    def public_key(self) -> str:
        return self["public_key"]
