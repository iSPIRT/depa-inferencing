# Runs on each cold start. Authenticate to Azure using the Function App's
# system-assigned managed identity so the reconcile module can call ARM.
if ($env:MSI_SECRET -or $env:IDENTITY_ENDPOINT) {
    Disable-AzContextAutosave -Scope Process | Out-Null
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    if ($env:SUBSCRIPTION_ID) {
        Set-AzContext -Subscription $env:SUBSCRIPTION_ID -ErrorAction SilentlyContinue | Out-Null
    }
}
