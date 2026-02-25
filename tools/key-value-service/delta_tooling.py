"""
Generate delta files from CSV (via data_cli) and upload to Azure File share.
Used by CI and local tooling to prepare KV test data.
"""
import logging
import subprocess
from pathlib import Path
from typing import Optional

from azure.storage.fileshare import ShareDirectoryClient, ShareFileClient
from azure.core.exceptions import ResourceExistsError

logger = logging.getLogger(__name__)


def generate_delta_from_csv(
    csv_path: Path,
    output_path: Path,
    data_cli_script: Optional[Path] = None,
) -> None:
    """Generate a delta file from CSV using data_cli.sh (Docker)."""
    script = data_cli_script or (Path(__file__).resolve().parent / "data_cli.sh")
    if not script.exists():
        raise FileNotFoundError(f"data_cli.sh not found: {script}")
    csv_path = csv_path.resolve()
    output_path = output_path.resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)
    logger.info("Generating delta file: %s -> %s", csv_path, output_path)
    result = subprocess.run(
        ["bash", str(script), "format_delta", str(csv_path), str(output_path)],
        capture_output=True,
        text=True,
        cwd=str(script.parent),
    )
    if result.returncode != 0:
        logger.warning(
            "Delta generation failed (exit %s). stderr: %s stdout: %s",
            result.returncode,
            (result.stderr or "").strip() or "(none)",
            (result.stdout or "").strip() or "(none)",
        )
        result.check_returncode()
    logger.info("Generated delta file: %s", output_path)


def upload_file_to_share(
    account_name: str,
    account_key: str,
    share_name: str,
    path_in_share: str,
    local_path: Path,
) -> None:
    """Upload a single file to an Azure File share (account key auth)."""
    local_path = Path(local_path).resolve()
    if not local_path.is_file():
        raise FileNotFoundError(f"Not a file: {local_path}")
    logger.info("Uploading delta file: %s -> share %s/%s", local_path.name, share_name, path_in_share)
    # path_in_share is the full path of the file in the share, e.g. "deltas/DELTA_0000000000000001"
    conn = f"DefaultEndpointsProtocol=https;AccountName={account_name};AccountKey={account_key};EndpointSuffix=core.windows.net"
    # Ensure parent directory exists in the share (Azure Files does not auto-create it)
    parts = path_in_share.replace("\\", "/").split("/")
    if len(parts) > 1:
        parent_path = "/".join(parts[:-1])
        dir_client = ShareDirectoryClient.from_connection_string(
            conn, share_name=share_name, directory_path=parent_path
        )
        try:
            dir_client.create_directory()
        except ResourceExistsError:
            pass
    client = ShareFileClient.from_connection_string(
        conn, share_name=share_name, file_path=path_in_share
    )
    with open(local_path, "rb") as f:
        client.upload_file(f)
    logger.info("Uploaded delta file: %s to %s/%s", local_path.name, share_name, path_in_share)


def generate_and_upload_delta(
    csv_path: Path,
    delta_name: str,
    account_name: str,
    account_key: str,
    share_name: str,
    share_path: str = "deltas",
    work_dir: Optional[Path] = None,
    data_cli_script: Optional[Path] = None,
) -> Path:
    """
    Generate a delta file from CSV (via data_cli) and upload it to an Azure File share.
    Single entry point for all delta generation + upload. Returns path to the local delta file.
    """
    csv_path = Path(csv_path).resolve()
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV not found: {csv_path}")
    work_dir = Path(work_dir) if work_dir is not None else csv_path.parent / "tmp"
    work_dir.mkdir(parents=True, exist_ok=True)
    local_delta = work_dir / delta_name
    generate_delta_from_csv(csv_path, local_delta, data_cli_script=data_cli_script)
    remote_path = f"{share_path.rstrip('/')}/{delta_name}"
    upload_file_to_share(
        account_name=account_name,
        account_key=account_key,
        share_name=share_name,
        path_in_share=remote_path,
        local_path=local_delta,
    )
    return local_delta
