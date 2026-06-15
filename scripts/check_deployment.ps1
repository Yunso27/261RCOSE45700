param(
    [string]$BaseUrl = "http://ec2-100-48-61-106.compute-1.amazonaws.com",
    [switch]$StrictFrontend
)

$ErrorActionPreference = "Stop"

function Join-Url {
    param(
        [string]$Base,
        [string]$Path
    )
    return $Base.TrimEnd("/") + "/" + $Path.TrimStart("/")
}

function Read-Url {
    param(
        [string]$Url,
        [string]$Method = "GET"
    )
    try {
        return Invoke-WebRequest -Uri $Url -Method $Method -UseBasicParsing -TimeoutSec 20
    } catch {
        $response = $_.Exception.Response
        if ($null -eq $response) {
            throw
        }
        return $_.Exception.Response
    }
}

function Get-StatusCode {
    param($Response)
    return [int]$Response.StatusCode
}

function Assert-Status {
    param(
        [string]$Name,
        $Response,
        [int[]]$Expected
    )

    $status = Get-StatusCode $Response
    if ($Expected -notcontains $status) {
        throw "$Name failed: expected $($Expected -join ', '), got $status"
    }
    Write-Host "[ok] $Name -> HTTP $status"
}

Write-Host "Checking SafeVlog3 deployment at $BaseUrl"

$root = Read-Url -Url $BaseUrl
Assert-Status -Name "frontend root" -Response $root -Expected @(200)

$health = Read-Url -Url (Join-Url $BaseUrl "health")
Assert-Status -Name "backend health" -Response $health -Expected @(200)
Write-Host "     health body: $($health.Content)"
