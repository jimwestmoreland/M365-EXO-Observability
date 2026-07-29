function Send-DatadogLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatadogApiKey,

        [Parameter(Mandatory = $true)]
        [string]$DatadogLogEndpoint,

        [Parameter(Mandatory = $true)]
        [object[]]$Records
    )

    if (-not $Records -or $Records.Count -eq 0) {
        return
    }

    $body = $Records | ConvertTo-Json -Depth 12

    Invoke-RestMethod `
        -Method Post `
        -Uri $DatadogLogEndpoint `
        -Headers @{
            "DD-API-KEY" = $DatadogApiKey
            "Content-Type" = "application/json"
        } `
        -Body $body
}