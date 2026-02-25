"""
Generate KV-style CSV content in Python with sequential numeric keys and random string values.
Format matches data_cli input: key, mutation_type, logical_commit_time, value, value_type.
Keys are sequential from key_start (key_start, key_start+1, ...) to simplify verification
(first and last key presence in delta).
"""
import random
import string
from pathlib import Path
from typing import Optional

CSV_HEADER = "key,mutation_type,logical_commit_time,value,value_type"


def _random_value(length: int = 16) -> str:
    return "".join(random.choices(string.ascii_letters + string.digits, k=length))


def generate_kv_csv(
    num_records: int,
    key_start: int = 0,
    seed: Optional[int] = None,
    logical_commit_time_base: int = 1680815895468155,
) -> tuple[str, list[int], list[str]]:
    """
    Generate CSV content for KV delta loading.
    Keys are sequential: key_start, key_start+1, ..., key_start+num_records-1.
    Values are random (optional seed for reproducibility).
    Returns:
        (csv_string, keys, values) so callers can verify first/last key presence.
    """
    if seed is not None:
        random.seed(seed)
    if num_records < 1:
        return CSV_HEADER + "\n", [], []
    keys = [key_start + i for i in range(num_records)]
    values = [_random_value() for _ in range(num_records)]
    rows = [CSV_HEADER]
    for i in range(num_records):
        ts = logical_commit_time_base + i
        rows.append(f"{keys[i]},UPDATE,{ts},{values[i]},string")
    return "\n".join(rows) + "\n", keys, values


def write_kv_csv(
    path: Path,
    num_records: int,
    key_start: int = 0,
    seed: Optional[int] = None,
    logical_commit_time_base: int = 1680815895468155,
) -> tuple[Path, list[int], list[str]]:
    """Write generated CSV to path. Creates parent dirs. Returns (path, keys, values)."""
    path = Path(path).resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    csv_str, keys, values = generate_kv_csv(
        num_records=num_records,
        key_start=key_start,
        seed=seed,
        logical_commit_time_base=logical_commit_time_base,
    )
    path.write_text(csv_str, encoding="utf-8")
    return path, keys, values
