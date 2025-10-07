#!/usr/bin/env python3
"""
Command-line interface for Secure Invoke
"""

import sys
import json
import logging
from pathlib import Path
from typing import Optional

import click
from rich.console import Console
from rich.logging import RichHandler
from rich.progress import Progress, SpinnerColumn, TextColumn

from .client import SecureInvokeClient
from .models import SecureInvokeConfig
from .batch import BatchProcessor
from .exceptions import SecureInvokeError

console = Console()


def setup_logging(verbose: bool = False):
    """Setup logging with rich handler"""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(message)s",
        handlers=[RichHandler(console=console, rich_tracebacks=True)]
    )


@click.group()
@click.version_option(version="1.0.0")
def cli():
    """Secure Invoke - Python client for encrypted API requests"""
    pass


@cli.command()
@click.option('--kms-host', required=True, help='KMS service host')
@click.option('--buyer-host', required=True, help="Bank's API Gateway host")
@click.option('--target-service', default='bfe', help='Target service (default: bfe)')
@click.option('--request-path', type=click.Path(exists=True), required=True, help='Path to request JSON file')
@click.option('--headers', help='HTTP headers as JSON string')
@click.option('--client-cert', type=click.Path(exists=True), help='Path to client certificate')
@click.option('--client-key', type=click.Path(exists=True), help='Path to client private key')
@click.option('--ca-cert', type=click.Path(exists=True), help='Path to CA certificate')
@click.option('--insecure', is_flag=True, help='Disable certificate validation (dev only)')
@click.option('--retries', default=3, type=int, help='Number of retry attempts')
@click.option('--verbose', is_flag=True, help='Enable verbose logging')
def invoke(
    kms_host: str,
    buyer_host: str,
    target_service: str,
    request_path: str,
    headers: Optional[str],
    client_cert: Optional[str],
    client_key: Optional[str],
    ca_cert: Optional[str],
    insecure: bool,
    retries: int,
    verbose: bool
):
    """Send a single encrypted request to the API"""
    setup_logging(verbose)
    
    try:
        # Parse headers
        headers_dict = {}
        if headers:
            headers_dict = json.loads(headers)
        
        # Create config
        config = SecureInvokeConfig(
            kms_host=kms_host,
            buyer_host=buyer_host,
            target_service=target_service,
            headers=headers_dict,
            client_cert=Path(client_cert) if client_cert else None,
            client_key=Path(client_key) if client_key else None,
            ca_cert=Path(ca_cert) if ca_cert else None,
            insecure=insecure,
            retries=retries,
            enable_verbose=verbose
        )
        
        # Read request
        with open(request_path) as f:
            request = json.load(f)
        
        # Create client and send request
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            progress.add_task("Sending request...", total=None)
            
            with SecureInvokeClient(config) as client:
                response = client.get_bids(request)
        
        # Print response
        console.print("\n[bold green]✓ Success![/bold green]")
        console.print("\n[bold]Response:[/bold]")
        console.print_json(data=response)
        
    except SecureInvokeError as e:
        console.print(f"\n[bold red]✗ Error:[/bold red] {str(e)}", style="red")
        sys.exit(1)
    except Exception as e:
        console.print(f"\n[bold red]✗ Unexpected error:[/bold red] {str(e)}", style="red")
        if verbose:
            console.print_exception()
        sys.exit(1)


@cli.command()
@click.option('--kms-host', required=True, help='KMS service host')
@click.option('--buyer-host', required=True, help="Bank's API Gateway host")
@click.option('--target-service', default='bfe', help='Target service (default: bfe)')
@click.option('--batch-file', type=click.Path(exists=True), required=True, help='Path to batch JSONL file')
@click.option('--headers', help='HTTP headers as JSON string')
@click.option('--client-cert', type=click.Path(exists=True), help='Path to client certificate')
@click.option('--client-key', type=click.Path(exists=True), help='Path to client private key')
@click.option('--ca-cert', type=click.Path(exists=True), help='Path to CA certificate')
@click.option('--insecure', is_flag=True, help='Disable certificate validation (dev only)')
@click.option('--max-concurrent', default=10, type=int, help='Max concurrent requests')
@click.option('--retries', default=3, type=int, help='Number of retry attempts')
@click.option('--output-dir', type=click.Path(), help='Output directory for logs')
@click.option('--verbose', is_flag=True, help='Enable verbose logging')
def batch(
    kms_host: str,
    buyer_host: str,
    target_service: str,
    batch_file: str,
    headers: Optional[str],
    client_cert: Optional[str],
    client_key: Optional[str],
    ca_cert: Optional[str],
    insecure: bool,
    max_concurrent: int,
    retries: int,
    output_dir: Optional[str],
    verbose: bool
):
    """Process multiple requests from a JSONL batch file"""
    setup_logging(verbose)
    
    try:
        # Parse headers
        headers_dict = {}
        if headers:
            headers_dict = json.loads(headers)
        
        # Create config
        config = SecureInvokeConfig(
            kms_host=kms_host,
            buyer_host=buyer_host,
            target_service=target_service,
            headers=headers_dict,
            client_cert=Path(client_cert) if client_cert else None,
            client_key=Path(client_key) if client_key else None,
            ca_cert=Path(ca_cert) if ca_cert else None,
            insecure=insecure,
            retries=retries,
            max_concurrent_requests=max_concurrent,
            enable_verbose=verbose
        )
        
        # Process batch
        batch_path = Path(batch_file)
        output_path = Path(output_dir) if output_dir else None
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            progress.add_task("Processing batch...", total=None)
            
            with BatchProcessor(config) as processor:
                result = processor.process_batch_file(batch_path, output_path)
        
        # Print summary
        console.print("\n[bold green]✓ Batch processing complete![/bold green]")
        console.print(f"\nTotal requests: {result.total}")
        console.print(f"[green]Successful: {result.successful}[/green]")
        console.print(f"[red]Failed: {result.failed}[/red]")
        console.print(f"Success rate: {result.success_rate:.1f}%")
        
        output_path = output_path or batch_path.parent
        console.print(f"\nLogs written to: {output_path}")
        
    except SecureInvokeError as e:
        console.print(f"\n[bold red]✗ Error:[/bold red] {str(e)}", style="red")
        sys.exit(1)
    except Exception as e:
        console.print(f"\n[bold red]✗ Unexpected error:[/bold red] {str(e)}", style="red")
        if verbose:
            console.print_exception()
        sys.exit(1)


@cli.command()
@click.option('--kms-host', required=True, help='KMS service host')
@click.option('--insecure', is_flag=True, help='Disable certificate validation')
@click.option('--verbose', is_flag=True, help='Enable verbose logging')
def test_kms(kms_host: str, insecure: bool, verbose: bool):
    """Test KMS connectivity and fetch public key"""
    setup_logging(verbose)
    
    try:
        from .kms import KMSKeyFetcher
        
        console.print(f"Testing KMS connectivity to: {kms_host}")
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            progress.add_task("Fetching key...", total=None)
            
            kms = KMSKeyFetcher(kms_host, insecure=insecure)
            key = kms.fetch_key()
        
        console.print("\n[bold green]✓ Success![/bold green]")
        console.print(f"\nKey ID: {key.id}")
        console.print(f"Key (truncated): {key.key[:50]}...")
        
    except Exception as e:
        console.print(f"\n[bold red]✗ Error:[/bold red] {str(e)}", style="red")
        if verbose:
            console.print_exception()
        sys.exit(1)


if __name__ == '__main__':
    cli()
