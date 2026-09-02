"""URL helpers that preserve any path prefix already present on a host.

The previous SDK used ``urllib.parse.urljoin(base, "/app/listpubkeys")`` which
*discards* any path component of ``base`` (because the endpoint begins with a
slash). That breaks clients whose KMS/offer hosts sit behind a path-based route
such as ``https://gateway.example.com/tenant-a``. These helpers instead append
the endpoint to the full host, keeping the prefix intact.
"""

from __future__ import annotations


def normalize_host(host: str, default_scheme: str = "https") -> str:
    host = (host or "").strip()
    if not host:
        return host
    if not host.startswith(("http://", "https://")):
        host = f"{default_scheme}://{host}"
    return host.rstrip("/")


def join_url(host: str, endpoint: str, default_scheme: str = "https") -> str:
    """Join ``host`` and ``endpoint`` without dropping ``host``'s path prefix.

    Examples::

        join_url("https://kms.example.com", "/app/listpubkeys")
            -> "https://kms.example.com/app/listpubkeys"
        join_url("https://gw.example.com/tenant-a", "/app/listpubkeys")
            -> "https://gw.example.com/tenant-a/app/listpubkeys"
        join_url("https://kms.example.com/app/listpubkeys", "")
            -> "https://kms.example.com/app/listpubkeys"
    """
    base = normalize_host(host, default_scheme)
    endpoint = (endpoint or "").strip()
    if not endpoint:
        return base
    return f"{base}/{endpoint.lstrip('/')}"
