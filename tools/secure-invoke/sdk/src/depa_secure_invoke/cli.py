"""Command-line interface for the DEPA secure-invoke SDK."""

from __future__ import annotations

import argparse
import json
import sys
from typing import Dict, List, Optional

from ._version import __version__
from .client import SecureInvokeClient
from .config import (
    DEFAULT_CACHE_TTL_SECONDS,
    DEFAULT_KMS_KEYS_ENDPOINT,
    DEFAULT_OFFER_ENDPOINT,
    DEFAULT_TARGET_SERVICE,
    SecureInvokeConfig,
)
from .errors import SecureInvokeError


def _parse_headers(raw: Optional[str]) -> Dict[str, str]:
    if not raw:
        return {}
    try:
        headers = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SecureInvokeError(f"--headers is not valid JSON: {exc}") from exc
    if not isinstance(headers, dict):
        raise SecureInvokeError("--headers must be a JSON object")
    return {str(k): str(v) for k, v in headers.items()}


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="secure-invoke",
        description=(
            "Encrypt, send and decrypt DEPA inferencing offer requests over "
            "REST (Azure) or gRPC (GCP)."
        ),
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    parser.add_argument(
        "--op",
        choices=["invoke", "encrypt", "keys", "batch"],
        default="invoke",
        help="invoke: full round-trip; encrypt: print ciphertext; "
        "keys: list KMS public keys; batch: invoke a .jsonl file concurrently",
    )

    kms = parser.add_argument_group("KMS")
    kms.add_argument("--kms-host", required=True, help="KMS base URL (path prefix preserved)")
    kms.add_argument(
        "--kms-keys-endpoint",
        default=DEFAULT_KMS_KEYS_ENDPOINT,
        help="KMS list-public-keys path (appended to --kms-host)",
    )

    offer = parser.add_argument_group("offer host")
    offer.add_argument("--offer-host", help="Offer host (BFE/OFE). host:port[/path]")
    offer.add_argument(
        "--offer-endpoint",
        default=DEFAULT_OFFER_ENDPOINT,
        help="REST endpoint path (ignored for gRPC)",
    )
    offer.add_argument(
        "--protocol", choices=["rest", "grpc"], default="rest",
        help="rest for Azure (envoy), grpc for GCP BFE",
    )
    offer.add_argument(
        "--target-service", default=DEFAULT_TARGET_SERVICE,
        help="Target service for the native backend (e.g. bfe, sfe)",
    )

    backend = parser.add_argument_group("backend")
    backend.add_argument(
        "--backend", choices=["auto", "python", "native"], default="auto",
        help="auto: rest->python (Azure), grpc->native (GCP); "
        "python: ctypes crypto; native: bundled invoke binary",
    )
    backend.add_argument(
        "--native-bin",
        help="Path to the native invoke binary (else SECURE_INVOKE_NATIVE_BIN / "
        "bundled / PATH)",
    )
    backend.add_argument(
        "--client-type", default="browser", help="browser or android (native backend)"
    )

    req = parser.add_argument_group("request")
    req.add_argument("--request", help="Inline request as a JSON string")
    req.add_argument("--request-file", help="Path to request .json/.jsonl file")

    tls = parser.add_argument_group("TLS / security")
    tls.add_argument("--insecure", action="store_true", help="Skip TLS verification (REST) / use plaintext (gRPC)")
    tls.add_argument("--client-cert", help="Client certificate file (mTLS)")
    tls.add_argument("--client-key", help="Client private key file (mTLS)")
    tls.add_argument("--ca-cert", help="CA certificate file")

    behaviour = parser.add_argument_group("behaviour")
    behaviour.add_argument("--headers", help="Extra headers as a JSON object")
    behaviour.add_argument("--client-ip", help="Client IP forwarded to the offer host")
    behaviour.add_argument("--retries", type=int, default=1, help="Attempts before giving up")
    behaviour.add_argument("--retry-delay", type=float, default=2.0, help="Seconds between retries")
    behaviour.add_argument("--timeout", type=float, default=20.0, help="Per-request timeout (seconds)")
    behaviour.add_argument("--max-workers", type=int, default=8, help="Concurrency for --op batch")

    cache = parser.add_argument_group("public key cache")
    cache.add_argument(
        "--cache-keys", action="store_true",
        help="Cache KMS public keys in-process (helps --op batch / library reuse)",
    )
    cache.add_argument(
        "--cache-file", metavar="PATH",
        help="Cache KMS public keys on disk at PATH, shared across CLI runs "
        "(implies --cache-keys)",
    )
    cache.add_argument(
        "--cache-ttl", type=int, default=DEFAULT_CACHE_TTL_SECONDS,
        help="Fallback cache TTL in seconds when the KMS sends no Cache-Control "
        "(also sent as a Cache-Control max-age request header)",
    )
    cache.add_argument(
        "--cache-ignore-server-headers", action="store_true",
        help="Ignore the KMS response Cache-Control/Expires and always use "
        "--cache-ttl",
    )

    parser.add_argument("--output", help="Write result JSON to this file instead of stdout")
    parser.add_argument("--verbose", action="store_true", help="Verbose diagnostics on stderr")
    return parser


def _config_from_args(args: argparse.Namespace) -> SecureInvokeConfig:
    return SecureInvokeConfig(
        kms_host=args.kms_host,
        kms_keys_endpoint=args.kms_keys_endpoint,
        offer_host=args.offer_host or "",
        offer_endpoint=args.offer_endpoint,
        protocol=args.protocol,
        backend=args.backend,
        target_service=args.target_service,
        native_bin=args.native_bin,
        client_type=args.client_type,
        insecure=args.insecure,
        client_cert=args.client_cert,
        client_key=args.client_key,
        ca_cert=args.ca_cert,
        headers=_parse_headers(args.headers),
        retries=args.retries,
        retry_delay=args.retry_delay,
        timeout=args.timeout,
        client_ip=args.client_ip,
        cache_keys=args.cache_keys,
        cache_file=args.cache_file,
        cache_ttl=args.cache_ttl,
        cache_respect_server=not args.cache_ignore_server_headers,
        verbose=args.verbose,
    )


def _emit(result, output: Optional[str]) -> None:
    text = json.dumps(result, indent=2)
    if output:
        with open(output, "w", encoding="utf-8") as handle:
            handle.write(text + "\n")
    else:
        print(text)


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)

    try:
        config = _config_from_args(args)

        if args.op == "keys":
            # Offer host not needed just to list keys.
            config.offer_host = config.offer_host or "unused:0"
            client = SecureInvokeClient(config)
            keys = client.kms.list_public_keys()
            _emit([dict(k) for k in keys], args.output)
            return 0

        if not config.offer_host:
            raise SecureInvokeError("--offer-host is required for this operation")

        with SecureInvokeClient(config) as client:
            if args.op == "encrypt":
                encrypted = client.encrypt(
                    request=args.request, request_file=args.request_file
                )
                _emit(
                    {
                        "key_id": encrypted.key_id,
                        "payload": encrypted.payload,
                        "ciphertext_b64": encrypted.ciphertext_b64,
                    },
                    args.output,
                )
                return 0

            if args.op == "batch":
                if not args.request_file:
                    raise SecureInvokeError("--request-file is required for --op batch")
                results = client.invoke_batch_file(
                    args.request_file, max_workers=args.max_workers
                )
                _emit(results, args.output)
                failed = [r for r in results if "error" in r]
                if failed:
                    print(f"{len(failed)}/{len(results)} request(s) failed", file=sys.stderr)
                    return 1
                return 0

            # default: invoke
            result = client.invoke(
                request=args.request, request_file=args.request_file
            )
            _emit(result, args.output)
            return 0

    except SecureInvokeError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
