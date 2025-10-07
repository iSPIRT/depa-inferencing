"""
Batch processing for Secure Invoke
"""

import logging
# import asyncio ## Using ThreadPoolExecutor instead of asyncio, since the batch processing is synchronous.
import json
from typing import List, Dict, Any, Optional
from pathlib import Path
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed

from .client import SecureInvokeClient
from .models import (
    SecureInvokeConfig,
    BatchRequestEntry,
    BatchResultEntry,
    BatchResult
)
from .exceptions import SecureInvokeError

logger = logging.getLogger(__name__)


class BatchProcessor:
    """
    Process multiple requests in batch with concurrency control and retry logic
    """
    
    def __init__(self, config: SecureInvokeConfig):
        """
        Initialize batch processor
        
        Args:
            config: Secure Invoke configuration
        """
        self.config = config
        self.client = SecureInvokeClient(config)
    
    def process_batch_file(
        self,
        batch_file: Path,
        output_dir: Optional[Path] = None
    ) -> BatchResult:
        """
        Process a batch file with multiple requests
        
        Args:
            batch_file: Path to JSONL file with requests
            output_dir: Directory to write success/failure logs (defaults to batch file directory)
            
        Returns:
            BatchResult with processing statistics
        """
        logger.info(f"Starting batch processing from {batch_file}")
        start_time = datetime.utcnow()
        
        # Read requests from file
        requests = self._read_batch_file(batch_file)
        logger.info(f"Loaded {len(requests)} requests from file")
        
        # Process requests with concurrency
        results = self._process_requests(requests)
        
        # Calculate statistics
        successful = sum(1 for r in results if r.success)
        failed = len(results) - successful
        
        batch_result = BatchResult(
            total=len(results),
            successful=successful,
            failed=failed,
            results=results
        )
        
        # Write logs
        if output_dir is None:
            output_dir = batch_file.parent
        
        self._write_logs(batch_result, output_dir)
        
        duration = (datetime.utcnow() - start_time).total_seconds()
        logger.info(
            f"Batch processing completed in {duration:.2f}s: "
            f"{successful} succeeded, {failed} failed "
            f"(success rate: {batch_result.success_rate:.1f}%)"
        )
        
        return batch_result
    
    def process_batch_list(
        self,
        requests: List[Dict[str, Any]]
    ) -> BatchResult:
        """
        Process a list of requests (programmatic interface)
        
        Args:
            requests: List of request dictionaries
            
        Returns:
            BatchResult with processing statistics
        """
        logger.info(f"Starting batch processing of {len(requests)} requests")
        
        # Convert to BatchRequestEntry format
        entries = [
            BatchRequestEntry(id=i, request=req)
            for i, req in enumerate(requests)
        ]
        
        # Process
        results = self._process_requests(entries)
        
        # Calculate statistics
        successful = sum(1 for r in results if r.success)
        failed = len(results) - successful
        
        return BatchResult(
            total=len(results),
            successful=successful,
            failed=failed,
            results=results
        )
    
    def _read_batch_file(self, batch_file: Path) -> List[BatchRequestEntry]:
        """
        Read batch file in JSONL format
        
        Args:
            batch_file: Path to JSONL file
            
        Returns:
            List of BatchRequestEntry objects
        """
        requests = []
        
        with open(batch_file, 'r') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                
                try:
                    data = json.loads(line)
                    entry = BatchRequestEntry(**data)
                    requests.append(entry)
                except Exception as e:
                    logger.warning(f"Skipping invalid line {line_num}: {e}")
                    continue
        
        return requests
    
    def _process_requests(
        self,
        requests: List[BatchRequestEntry]
    ) -> List[BatchResultEntry]:
        """
        Process requests with concurrency control
        
        Args:
            requests: List of requests to process
            
        Returns:
            List of results
        """
        results: List[BatchResultEntry] = []
        
        # Use ThreadPoolExecutor for concurrent processing
        with ThreadPoolExecutor(max_workers=self.config.max_concurrent_requests) as executor:
            # Submit all tasks
            future_to_request = {
                executor.submit(self._process_single_request, req): req
                for req in requests
            }
            
            # Collect results as they complete
            for future in as_completed(future_to_request):
                request = future_to_request[future]
                try:
                    result = future.result()
                    results.append(result)
                    
                    if result.success:
                        logger.debug(f"Request {result.id} succeeded after {result.attempts} attempts")
                    else:
                        logger.warning(f"Request {result.id} failed: {result.error}")
                        
                except Exception as e:
                    logger.error(f"Unexpected error processing request {request.id}: {e}")
                    results.append(BatchResultEntry(
                        id=request.id,
                        attempts=1,
                        success=False,
                        error=str(e)
                    ))
        
        return results
    
    def _process_single_request(
        self,
        request: BatchRequestEntry
    ) -> BatchResultEntry:
        """
        Process a single request with retry logic
        
        Args:
            request: Request entry
            
        Returns:
            Result entry
        """
        last_error = None
        
        for attempt in range(1, self.config.retries + 1):
            try:
                response = self.client.get_bids(request.request)
                
                return BatchResultEntry(
                    id=request.id,
                    attempts=attempt,
                    success=True,
                    response=response
                )
                
            except SecureInvokeError as e:
                last_error = str(e)
                logger.debug(f"Request {request.id} attempt {attempt} failed: {e}")
                
                if attempt < self.config.retries:
                    # Wait before retry
                    import time
                    time.sleep(self.config.retry_delay_ms / 1000.0)
            
            except Exception as e:
                last_error = str(e)
                logger.error(f"Unexpected error on request {request.id}: {e}")
                break
        
        return BatchResultEntry(
            id=request.id,
            attempts=self.config.retries,
            success=False,
            error=last_error
        )
    
    def _write_logs(self, result: BatchResult, output_dir: Path) -> None:
        """
        Write success and failure logs
        
        Args:
            result: Batch result
            output_dir: Directory to write logs
        """
        # Write success log
        success_log_path = output_dir / "success_log.jsonl"
        with open(success_log_path, 'w') as f:
            for entry in result.results:
                if entry.success:
                    log_entry = {
                        "id": entry.id,
                        "attempts": entry.attempts,
                        "raw_json_response": entry.response,
                        "timestamp": entry.timestamp.isoformat()
                    }
                    f.write(json.dumps(log_entry) + '\n')
        
        logger.info(f"Wrote success log to {success_log_path}")
        
        # Write failure log
        failure_log_path = output_dir / "failure_log.jsonl"
        with open(failure_log_path, 'w') as f:
            for entry in result.results:
                if not entry.success:
                    log_entry = {
                        "id": entry.id,
                        "attempts": entry.attempts,
                        "error": entry.error,
                        "timestamp": entry.timestamp.isoformat()
                    }
                    f.write(json.dumps(log_entry) + '\n')
        
        logger.info(f"Wrote failure log to {failure_log_path}")
    
    def close(self) -> None:
        """Close the batch processor"""
        self.client.close()
    
    def __enter__(self):
        """Context manager entry"""
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()
