#!/usr/bin/env python3
"""
Generate a delta file from CSV (via data_cli.sh) and upload it to an Azure File share.
Reads storage config from env: KV_STORAGE_ACCOUNT, KV_STORAGE_KEY, KV_SHARE_NAME, KV_SHARE_PATH.
CSV can be read from a file (--csv) or generated in Python (--num-records).
Usage:
  python generate_and_upload_delta.py --delta-name DELTA_0000000000000001 --num-records 2
  python generate_and_upload_delta.py --csv data.csv --delta-name DELTA_0000000000000001
"""
import argparse
import logging
import os
import sys
from pathlib import Path

_ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(_ROOT))

# Show delta_tooling logs when run as script
logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

from delta_tooling import generate_and_upload_delta
from csv_generator import write_kv_csv


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate delta from CSV and upload to Azure File share."
    )
    parser.add_argument(
        "--csv",
        type=Path,
        default=None,
        help="Input CSV path (ignored if --num-records is set)",
    )
    parser.add_argument(
        "--num-records",
        type=int,
        default=0,
        metavar="N",
        help="Generate CSV with N records (random keys/values). Overrides --csv if set.",
    )
    parser.add_argument(
        "--key-start",
        type=int,
        default=0,
        metavar="K",
        help="First key for sequential keys (default 0). Keys are key_start, key_start+1, ...",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        metavar="S",
        help="RNG seed for reproducible values when using --num-records.",
    )
    parser.add_argument(
        "--delta-name",
        required=True,
        help="Output delta file name, e.g. DELTA_0000000000000001",
    )
    parser.add_argument(
        "--work-dir",
        type=Path,
        default=_ROOT / "tmp",
        help="Directory for generated delta file before upload",
    )
    args = parser.parse_args()

    account = os.environ.get("KV_STORAGE_ACCOUNT")
    key = os.environ.get("KV_STORAGE_KEY")
    share_name = os.environ.get("KV_SHARE_NAME")
    share_path = os.environ.get("KV_SHARE_PATH", "deltas")
    if not all([account, key, share_name]):
        print(
            "Set KV_STORAGE_ACCOUNT, KV_STORAGE_KEY, KV_SHARE_NAME (and optionally KV_SHARE_PATH)",
            file=sys.stderr,
        )
        return 1

    work_dir = args.work_dir.resolve()
    work_dir.mkdir(parents=True, exist_ok=True)

    if args.num_records and args.num_records >= 1:
        csv_path, _, _ = write_kv_csv(
            work_dir / "generated.csv",
            num_records=args.num_records,
            key_start=args.key_start,
            seed=args.seed,
        )
        logging.info("Generated CSV with %s record(s) at %s", args.num_records, csv_path)
    else:
        csv_path = (args.csv if args.csv and args.csv.is_absolute() else _ROOT / args.csv) if args.csv else _ROOT / "data.csv"
        if not csv_path.exists():
            print(f"CSV not found: {csv_path}", file=sys.stderr)
            return 1

    generate_and_upload_delta(
        csv_path=csv_path,
        delta_name=args.delta_name,
        account_name=account,
        account_key=key,
        share_name=share_name,
        share_path=share_path,
        work_dir=work_dir,
    )
    logging.info("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
