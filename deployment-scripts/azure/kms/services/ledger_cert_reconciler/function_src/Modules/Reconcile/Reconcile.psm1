# Copyright (c) iSPIRT.
# Licensed under the Apache License, Version 2.0.
#
# Reconciles the Application Gateway's trusted root certificate for the
# Confidential Ledger backend against the ledger's current TLS identity.
#
# When the Confidential Ledger (CCF) restarts, it regenerates its self-signed
# service identity certificate. The gateway keeps trusting the previous cert,
# so backend TLS validation fails and clients receive 502s. This function
# fetches the live identity certificate and, if it differs from what is
# currently stored on the gateway, updates the trusted root certificate.
#
# Steady-state runs compare against the certificate already on the gateway, so
# a healthy deployment performs no writes. After an update, the thumbprint is
# also stored as the gateway tag `ledgerRootThumbprint` as a fast path.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LedgerIdentityCertificate {
    param(
        [Parameter(Mandatory = $true)][string]$BaseUrl,
        [Parameter(Mandatory = $true)][string]$LedgerName
    )

    $uri = "{0}/ledgerIdentity/{1}" -f $BaseUrl.TrimEnd('/'), $LedgerName
    $resp = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 30
    if (-not $resp.ledgerTlsCertificate) {
        throw "Ledger identity endpoint returned no ledgerTlsCertificate for '$LedgerName' ($uri)."
    }
    return [string]$resp.ledgerTlsCertificate
}

function Get-StoredCertificateThumbprint {
    param(
        $TrustedRootCertificate
    )

    if (-not $TrustedRootCertificate -or -not $TrustedRootCertificate.Data) {
        return $null
    }

    try {
        $bytes = [Convert]::FromBase64String([string]$TrustedRootCertificate.Data)
        # Entries created by Terraform/az CLI hold base64 of the PEM text; entries
        # written by the Az trusted-root cmdlets hold base64 of the DER bytes.
        $asText = [System.Text.Encoding]::ASCII.GetString($bytes)
        if ($asText -match 'BEGIN CERTIFICATE') {
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($asText)
            return $cert.Thumbprint
        }
        $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($bytes)
        return $cert.Thumbprint
    }
    catch {
        Write-Warning ("Unable to parse stored trusted root certificate: " + $_.Exception.Message)
        return $null
    }
}

function Invoke-LedgerCertReconcile {
    <#
    .SYNOPSIS
      Ensure the Application Gateway trusts the ledger's current TLS certificate.
    .PARAMETER WhatIf
      When set, reports whether an update is needed without writing.
    #>
    [CmdletBinding()]
    param(
        [switch]$WhatIf
    )

    $rg        = $env:AGW_RESOURCE_GROUP
    $agwName   = $env:AGW_NAME
    $ledger    = $env:LEDGER_NAME
    $rootName  = if ($env:ROOT_CERT_NAME) { $env:ROOT_CERT_NAME } else { 'ledger-root-cert' }
    $baseUrl   = if ($env:LEDGER_IDENTITY_BASE_URL) { $env:LEDGER_IDENTITY_BASE_URL } else { 'https://identity.confidential-ledger.core.azure.com' }

    foreach ($pair in @{ AGW_RESOURCE_GROUP = $rg; AGW_NAME = $agwName; LEDGER_NAME = $ledger }.GetEnumerator()) {
        if (-not $pair.Value) { throw "Required app setting '$($pair.Key)' is not set." }
    }

    $pem = Get-LedgerIdentityCertificate -BaseUrl $baseUrl -LedgerName $ledger
    $liveCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($pem)
    $liveThumbprint = $liveCert.Thumbprint

    $gw = Get-AzApplicationGateway -Name $agwName -ResourceGroupName $rg

    # Prefer the certificate currently stored on the gateway so the first run
    # is a true no-op when already correct. Tag is only a fallback.
    $existing = Get-AzApplicationGatewayTrustedRootCertificate -ApplicationGateway $gw -Name $rootName -ErrorAction SilentlyContinue
    $storedThumbprint = Get-StoredCertificateThumbprint -TrustedRootCertificate $existing
    if (-not $storedThumbprint -and $gw.Tag -and $gw.Tag.ContainsKey('ledgerRootThumbprint')) {
        $storedThumbprint = $gw.Tag['ledgerRootThumbprint']
    }

    if ($liveThumbprint -eq $storedThumbprint) {
        return [pscustomobject]@{
            changed    = $false
            thumbprint = $liveThumbprint
            message    = 'up-to-date'
        }
    }

    if ($WhatIf) {
        return [pscustomobject]@{
            changed    = $true
            thumbprint = $liveThumbprint
            previous   = $storedThumbprint
            message    = 'update-required (whatif)'
        }
    }

    # The trusted-root cmdlets take a certificate file path only; they load it
    # into an X509Certificate2 and store the DER export. Stage the live cert in
    # the writable temp directory for the duration of the call.
    $certFile = Join-Path ([System.IO.Path]::GetTempPath()) ("ledger-root-{0}.cer" -f [guid]::NewGuid())
    try {
        $der = $liveCert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
        [System.IO.File]::WriteAllBytes($certFile, $der)

        if ($existing) {
            Set-AzApplicationGatewayTrustedRootCertificate -ApplicationGateway $gw -Name $rootName -CertificateFile $certFile | Out-Null
        }
        else {
            Add-AzApplicationGatewayTrustedRootCertificate -ApplicationGateway $gw -Name $rootName -CertificateFile $certFile | Out-Null
        }
    }
    finally {
        Remove-Item -LiteralPath $certFile -Force -ErrorAction SilentlyContinue
    }

    $tags = @{}
    if ($gw.Tag) {
        foreach ($k in $gw.Tag.Keys) { $tags[$k] = $gw.Tag[$k] }
    }
    $tags['ledgerRootThumbprint'] = $liveThumbprint
    $gw.Tag = $tags

    Set-AzApplicationGateway -ApplicationGateway $gw | Out-Null

    return [pscustomobject]@{
        changed    = $true
        thumbprint = $liveThumbprint
        previous   = $storedThumbprint
        message    = 'updated'
    }
}

Export-ModuleMember -Function Invoke-LedgerCertReconcile, Get-LedgerIdentityCertificate
