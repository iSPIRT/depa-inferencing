"""Helpers to load request payloads from files or inline values.

Unlike the previous SDK, file vs inline is explicit (no fragile "does this look
like a path?" heuristic): callers pass either ``request`` (dict/JSON string) or
``request_file`` (path to a ``.json`` / ``.jsonl`` file).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, List, Union

from .errors import ConfigError

RequestLike = Union[Dict[str, Any], str]


def _unwrap(obj: Any) -> Dict[str, Any]:
    """Unwrap ``{"id": .., "request": {..}}`` envelopes to the inner request."""
    if isinstance(obj, dict) and "request" in obj and isinstance(obj["request"], dict):
        return obj["request"]
    if not isinstance(obj, dict):
        raise ConfigError("request payload must be a JSON object")
    return obj


def load_request(
    request: Union[RequestLike, None] = None,
    request_file: Union[str, None] = None,
) -> Dict[str, Any]:
    """Return a single request dict from ``request`` or ``request_file``."""
    if request is not None and request_file is not None:
        raise ConfigError("provide either request or request_file, not both")
    if request is None and request_file is None:
        raise ConfigError("one of request or request_file is required")

    if request_file is not None:
        return _load_first_from_file(request_file)

    if isinstance(request, dict):
        return _unwrap(request)
    if isinstance(request, str):
        try:
            return _unwrap(json.loads(request))
        except json.JSONDecodeError as exc:
            raise ConfigError(f"request is not valid JSON: {exc}") from exc
    raise ConfigError(f"unsupported request type: {type(request).__name__}")


def _load_first_from_file(path: str) -> Dict[str, Any]:
    file_path = Path(path)
    if not file_path.is_file():
        raise ConfigError(f"request file not found: {path}")
    if file_path.suffix.lower() == ".jsonl":
        rows = load_batch_from_file(path)
        if not rows:
            raise ConfigError(f"jsonl file is empty: {path}")
        return rows[0]
    try:
        return _unwrap(json.loads(file_path.read_text(encoding="utf-8")))
    except json.JSONDecodeError as exc:
        raise ConfigError(f"invalid JSON in {path}: {exc}") from exc


def load_batch_from_file(path: str) -> List[Dict[str, Any]]:
    """Load a batch of requests from a ``.jsonl`` (or single-object ``.json``)."""
    file_path = Path(path)
    if not file_path.is_file():
        raise ConfigError(f"request file not found: {path}")

    if file_path.suffix.lower() != ".jsonl":
        return [_unwrap(json.loads(file_path.read_text(encoding="utf-8")))]

    rows: List[Dict[str, Any]] = []
    with file_path.open("r", encoding="utf-8") as handle:
        for line_no, line in enumerate(handle, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(_unwrap(json.loads(line)))
            except json.JSONDecodeError as exc:
                raise ConfigError(f"{path}:{line_no}: invalid JSON: {exc}") from exc
    return rows
