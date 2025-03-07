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
    $null = New-Item -Path $BaseLogDirectory -ItemType Directory -Force
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
  RemediationType = "Remediation"
  CompanyName     = $CompanyName
}

Start-IntuneRemediationLog @IntuneRemediationLogParams
#endregion Log information

#region Variables
# If task name is changed, then a new task will be created. The old task will not be removed.
$TaskName = "PaperCut MF Client Zero Install"
$TaskPath = "\$CompanyName\"

# Variables modified here will need to be updated in the Detect-PaperCutMFClientZeroInstall.ps1 script.
# Changing these variables and redeploying will update the task to the new values.
$Description = $Description
$PrintServer = "IP"
$ExecutablePath = "\\$PrintServer\PCClient\win\pc-client.exe"
$ExecutableArguments = "--silent"
#endregion Variables

$TaskAction = @{
  Execute  = $ExecutablePath
  Argument = $ExecutableArguments
}

$TaskTriggers = @(
  New-ScheduledTaskTrigger -AtLogOn
  New-ScheduledTaskTrigger -Daily -At "08:00AM"
)

$TaskSettingsParams = @{
  AllowStartIfOnBatteries    = $true
  DontStopIfGoingOnBatteries = $true
  StartWhenAvailable         = $true
  RunOnlyIfNetworkAvailable  = $true
  ExecutionTimeLimit         = (New-TimeSpan -Hours 72)
  MultipleInstances          = "IgnoreNew"
}

$TaskPrincipal = New-ScheduledTaskPrincipal -GroupId "S-1-5-4" -RunLevel Limited

$TaskParams = @{
  TaskName    = $TaskName
  TaskPath    = $TaskPath
  Description = $Description
  Action      = New-ScheduledTaskAction @TaskAction
  Trigger     = $TaskTriggers
  Settings    = New-ScheduledTaskSettingsSet @TaskSettingsParams
  Principal   = $TaskPrincipal
}

try {
  # Remediation was called. The task is not compliant and needs to be removed.
  Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue -Confirm:$false

  # Register the task again to ensure it is compliant.
  Register-ScheduledTask @TaskParams

  # Start the task to ensure it is running.
  Start-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath
}
catch {
  Write-Error -Message "Error during task compliance: $($_.Exception.Message)"
  exit 1
}
finally {
  Stop-Transcript
}