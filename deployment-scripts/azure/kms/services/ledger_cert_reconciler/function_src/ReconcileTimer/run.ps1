param($Timer)

try {
    $result = Invoke-LedgerCertReconcile
    Write-Host ("ledger-cert reconcile: " + ($result | ConvertTo-Json -Compress))
}
catch {
    Write-Error ("ledger-cert reconcile failed: " + ($_ | Out-String))
    throw
}
