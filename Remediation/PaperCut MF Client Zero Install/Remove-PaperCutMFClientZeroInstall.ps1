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
    param (
        [string]$Remediation,
        [string]$RemediationType,
        [string]$CompanyName
    )

    $BaseLogDirectory = Join-Path -Path "C:\ProgramData" -ChildPath "$CompanyName\Intune\Remediation\$Remediation"

    if (-not (Test-Path -Path $BaseLogDirectory)) {
        New-Item -Path $BaseLogDirectory -ItemType Directory -Force | Out-Null
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
    Remediation     = "PaperCutMFClientZeroInstall"
    RemediationType = "Removal"
    CompanyName     = $CompanyName
}

Start-IntuneRemediationLog @IntuneRemediationLogParams
#endregion Log information

#region Variables
<#
Company and task-specific variables to define the expected state of the scheduled task:
- TaskName: The name of the scheduled task.
- TaskPath: The path where the task is stored in the Task Scheduler library.
#>
$TaskName = "PaperCut MF Client Zero Install"
$TaskPath = "\$CompanyName\"
#endregion Variables

try {
    Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop -Confirm:$false
    Write-Output "`nScheduled task [$TaskName] unregistered successfully.`n"
}
catch {
    Write-Error "Failed to unregister scheduled task '$TaskName'. Error: $($_.Exception.Message)"
}
finally {
    Stop-Transcript
}