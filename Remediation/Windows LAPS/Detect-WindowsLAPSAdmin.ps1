# Description: Checks to see if the Administrator account is present and enabled.
[CmdletBinding(SupportsShouldProcess)]
param ()

<#
.SYNOPSIS
Starts a transcript log for the Intune remediation script.

.DESCRIPTION
This function starts a transcript log for the Intune remediation script. The log is saved to the C:\ProgramData\$CompanyName\Intune\Remediation\$Remediation directory.

.PARAMETER Remediation
The name of the remediation being performed.

.PARAMETER RemediationType
The type of remediation being performed.

.PARAMETER CompanyName
The name of the company for logging directory.

.EXAMPLE
Start-IntuneRemediationLog -Remediation "PaperCutMFClientZeroInstall" -RemediationType "Detection" -CompanyName "Company"
#>
function Start-IntuneRemediationLog {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Remediation,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RemediationType,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$CompanyName
    )

    $BaseLogDirectory = Join-Path -Path "C:\ProgramData" -ChildPath "$CompanyName\Intune\Remediation\$Remediation"

    if (-not (Test-Path -Path $BaseLogDirectory)) {
        if ($PSCmdlet.ShouldProcess($BaseLogDirectory, "Create directory")) {
            New-Item -Path $BaseLogDirectory -ItemType Directory -Force | Out-Null
        }
    }

    $ResolvedLogDirectory = (Resolve-Path -Path $BaseLogDirectory).Path
    $LogFile = Join-Path -Path $ResolvedLogDirectory -ChildPath "$Remediation.$RemediationType.log"

    try {
        Start-Transcript -Path $LogFile -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to start transcript logging. Error: $($_.Exception.Message)"
    }
}

#region Log Information
<#
    Define log information
#>
$CompanyName = "Company"

$IntuneRemediationLogParams = @{
    Remediation     = "LAPSAdmin"
    RemediationType = "Detection"
    CompanyName     = $CompanyName
}

Start-IntuneRemediationLog @IntuneRemediationLogParams
#endregion Log information

$GetLocalUserSplat = @{
    Name        = "Administrator"
    ErrorAction = "Stop"
}

try {
    $User = Get-LocalUser @GetLocalUserSplat

    if ($User -and $User.Enabled) {
        Write-Output -InputObject "User [$($GetLocalUserSplat.Name)] present and enabled"
        exit 0
    }
}
catch {
    Write-Output -InputObject $_.Exception.Message
    Write-Output -InputObject "Remediation required."
    exit 1
}
finally {
    Stop-Transcript -WhatIf:$false
}