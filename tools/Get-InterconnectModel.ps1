<#
.SYNOPSIS
  Estimates cost, capacity headroom and availability for a multicloud private interconnect.

.DESCRIPTION
  Illustrative model for executive decision-making. Rates are placeholders and MUST be
  replaced with signed contract figures before any funding decision.

.EXAMPLE
  .\Get-InterconnectModel.ps1 -PeakGbps 8 -MonthlyEgressTB 120 -ProviderPortCostUSD 2200 -Redundancy 2
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][double]$PeakGbps,
    [Parameter(Mandatory)][double]$MonthlyEgressTB,
    [double]$ProviderPortCostUSD = 2200,       # REPLACE: monthly port fee per circuit
    [double]$CrossConnectCostUSD = 300,        # REPLACE: monthly cross-connect fee per circuit
    [double]$EgressRateUSDPerGB = 0.02,        # REPLACE: contracted data-transfer rate
    [double]$OneTimeEngineeringUSD = 150000,  # REPLACE: one-time engineering estimate
    [int]$CircuitsPerFacility = 2,             # Two circuits per facility for LAG resilience
    [int]$Redundancy = 2,                      # Number of independent facilities
    [double]$CircuitAvailability = 0.9995,     # REPLACE: contracted SLA per circuit
    [double]$Headroom = 0.30,                  # Target spare capacity
    [int]$CloudsConnected = 3
)

$ErrorActionPreference = 'Stop'

$circuitCount      = $CircuitsPerFacility * $Redundancy * $CloudsConnected
$monthlyPorts      = $circuitCount * $ProviderPortCostUSD
$monthlyXConnect   = $circuitCount * $CrossConnectCostUSD
$monthlyEgressGB   = $MonthlyEgressTB * 1000
$monthlyEgressCost = $monthlyEgressGB * $EgressRateUSDPerGB
$monthlyTotal      = $monthlyPorts + $monthlyXConnect + $monthlyEgressCost
$annualTotal       = $monthlyTotal * 12
$year1Total        = $annualTotal + $OneTimeEngineeringUSD

$perFacilityGbps   = $PeakGbps * (1 + $Headroom)
$capacityPerSiteGbps = $PeakGbps
$survivesFacilityLoss = ($Redundancy -ge 2) -and ($capacityPerSiteGbps -ge $PeakGbps)

# Probability both facilities fail independently in a given year (per cloud path)
$singlePathAvail = [math]::Pow($CircuitAvailability, $CircuitsPerFacility)
$facilityAvail   = $singlePathAvail
$pathAvail       = 1 - [math]::Pow((1 - $facilityAvail), $Redundancy)
$minutesPerYearDown = (1 - $pathAvail) * 525600

$result = [pscustomobject]@{
    CircuitsTotal         = $circuitCount
    MonthlyPortFeesUSD    = [math]::Round($monthlyPorts, 0)
    MonthlyCrossConnectUSD = [math]::Round($monthlyXConnect, 0)
    MonthlyEgressUSD      = [math]::Round($monthlyEgressCost, 0)
    MonthlyTotalUSD       = [math]::Round($monthlyTotal, 0)
    AnnualRunUSD          = [math]::Round($annualTotal, 0)
    Year1IncludingEngUSD  = [math]::Round($year1Total, 0)
    PerFacilityCapacityGbps = [math]::Round($perFacilityGbps, 2)
    SurvivesFacilityLoss  = $survivesFacilityLoss
    PathAvailabilityPct   = [math]::Round($pathAvail * 100, 4)
    ExpectedDowntimeMinPerYear = [math]::Round($minutesPerYearDown, 2)
}

Write-Host ""
Write-Host "Multicloud Private Interconnect: Executive Model" -ForegroundColor Cyan
Write-Host "Illustrative figures. Replace REPLACE values with contract data." -ForegroundColor Yellow
Write-Host ""
$result | Format-List
$result
