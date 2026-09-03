param($Request, $TriggerMetadata)

# Triggered on demand (e.g. by an Azure Monitor action group when the ledger
# backend goes unhealthy) to reconcile immediately instead of waiting for the
# next timer tick.
try {
    $result = Invoke-LedgerCertReconcile
    Write-Host ("ledger-cert reconcile (http): " + ($result | ConvertTo-Json -Compress))
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [System.Net.HttpStatusCode]::OK
            ContentType = "application/json"
            Body        = ($result | ConvertTo-Json -Compress)
        })
}
catch {
    $message = ($_ | Out-String)
    Write-Error ("ledger-cert reconcile (http) failed: " + $message)
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode  = [System.Net.HttpStatusCode]::InternalServerError
            ContentType = "application/json"
            Body        = (@{ error = $message } | ConvertTo-Json -Compress)
        })
}
