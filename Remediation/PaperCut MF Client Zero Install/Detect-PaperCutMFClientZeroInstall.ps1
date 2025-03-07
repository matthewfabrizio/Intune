function Set-Compliance {
    param (
        [string]$Field,
        [string]$Expected,
        [string]$Actual,
        [ref]$ComplianceList
    )

    if ($Expected -ne $Actual) {
        $ComplianceList.Value.Add([PSCustomObject]@{
                Status   = "Noncompliant"
                Field    = $Field
                Expected = $Expected
                Actual   = $Actual
            })
    }
}

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
    RemediationType = "Detection"
    CompanyName     = $CompanyName
}

Start-IntuneRemediationLog @IntuneRemediationLogParams
#endregion Log information

#region Variables
# If task name is changed, then a new task will be created.
$TaskName = "PaperCut MF Client Zero Install"
$TaskPath = "\$CompanyName\"

# Variables modified here will need to be updated in the Set-PaperCutMFClientZeroInstall.ps1 script.
# Changing these variables and redeploying will update the task to the new values.
$Description = "This task runs the PaperCut MF Client executable directly from the print server to stay up to date with the server."
$PrintServer = "IP"
$ExecutablePath = "\\$PrintServer\PCClient\win\pc-client.exe"
$ExecutableArguments = "--silent"
#endregion Variables

# If the task is set to be removed, update the task name so the remediation script will run.
# Do not update the removal script with this task name.
# This should be set to $true only when a separate remediation flow is created in Intune specifically for removing, else keep $false
$Removal = $false
if ($Removal) { $TaskName = "PaperCut MF Client Zero Install (Removal)" }

<#
PowerShell cmdlets don't provide all the details of a scheduled task, so we need to provide the expected XML structure to compare the task.

Only administrators can modify the task on the system, but it's still good to verify the details for compliance.

Verify important values to ensure the task is compliant. If other values are modified, the task may still be compliant.
- RegistrationInfo (Description, URI)
- Triggers (LogonTrigger, CalendarTrigger)
- Settings (Enabled)
- Actions (Command, Arguments)
#>
$ExpectedXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>$Description</Description>
    <URI>\$CompanyName\$TaskName</URI>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <CalendarTrigger>
      <StartBoundary>2025-04-06T08:00:00-05:00</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <GroupId>S-1-5-4</GroupId>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <Duration>PT10M</Duration>
      <WaitTimeout>PT1H</WaitTimeout>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$ExecutablePath</Command>
      <Arguments>$ExecutableArguments</Arguments>
    </Exec>
  </Actions>
</Task>
"@

try {
    $CurrentTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop
    
    # Get the current task XML
    $CurrentTaskXml = $CurrentTask | Export-ScheduledTask

    # Convert the XML strings to XML objects for comparison
    [xml]$CurrentXmlDoc = $CurrentTaskXml
    [xml]$ExpectedXmlDoc = $ExpectedXml

    $Compliance = [System.Collections.Generic.List[PSObject]]::new()

    <#
    Compare Task Registration Info (Description, URI)
    #>
    if ($CurrentXmlDoc.Task.RegistrationInfo.Description -ne $ExpectedXmlDoc.Task.RegistrationInfo.Description) {
        $DescriptionCompliance = @{
            Status   = "Noncompliant"
            Field    = "Task.RegistrationInfo.Description"
            Expected = $ExpectedXmlDoc.Task.RegistrationInfo.Description
            Actual   = $CurrentXmlDoc.Task.RegistrationInfo.Description
        }

        Set-Compliance @DescriptionCompliance -ComplianceList ([ref]$Compliance)
    }
    if ($CurrentXmlDoc.Task.RegistrationInfo.URI -ne $ExpectedXmlDoc.Task.RegistrationInfo.URI) {
        $RegistrationInfoCompliance = @{
            Status   = "Noncompliant"
            Field    = "Task.RegistrationInfo.URI"
            Expected = $ExpectedXmlDoc.Task.RegistrationInfo.URI
            Actual   = $CurrentXmlDoc.Task.RegistrationInfo.URI
        }

        Set-Compliance @RegistrationInfoCompliance -ComplianceList ([ref]$Compliance)
    }

    <#
    Compare Triggers

    Verify
    - At log on: Enabled
    - Daily: Enabled
    #>
    if ($CurrentXmlDoc.Task.Triggers.LogonTrigger.Enabled -ne $ExpectedXmlDoc.Task.Triggers.LogonTrigger.Enabled) {
        $LogonTriggerCompliance = @{
            Status   = "Noncompliant"
            Field    = "Task.Triggers.LogonTrigger.Enabled"
            Expected = $ExpectedXmlDoc.Task.Triggers.LogonTrigger.Enabled
            Actual   = $CurrentXmlDoc.Task.Triggers.LogonTrigger.Enabled
        }

        Set-Compliance @LogonTriggerCompliance -ComplianceList ([ref]$Compliance)
    }

    if ($CurrentXmlDoc.Task.Triggers.CalendarTrigger.Enabled -ne $ExpectedXmlDoc.Task.Triggers.CalendarTrigger.Enabled) {
        $CalendarTriggerCompliance = @{
            Status   = "Noncompliant"
            Field    = "Task.Triggers.CalendarTrigger.Enabled"
            Expected = $ExpectedXmlDoc.Task.Triggers.CalendarTrigger.Enabled
            Actual   = $CurrentXmlDoc.Task.Triggers.CalendarTrigger.Enabled
        }

        Set-Compliance @CalendarTriggerCompliance -ComplianceList ([ref]$Compliance)
    }

    <#
    Compare Settings

    Verify the task is not disabled.
    #> 
    if ($CurrentXmlDoc.Task.Settings.Enabled -ne $ExpectedXmlDoc.Task.Settings.Enabled) {
        $TaskEnabledCompliance = @{
            Status   = "Noncompliant"
            Field    = "Task.Settings.Enabled"
            Expected = $ExpectedXmlDoc.Task.Settings.Enabled
            Actual   = $CurrentXmlDoc.Task.Settings.Enabled
        }

        Set-Compliance @TaskEnabledCompliance -ComplianceList ([ref]$Compliance)
    }

    <#
    Compare Actions (Command and Arguments)
    #>
    if ($CurrentXmlDoc.Task.Actions.Exec.Command -ne $ExpectedXmlDoc.Task.Actions.Exec.Command) {
        $ActionCommandCompliance = @{
            Status   = "Noncompliant"
            Field    = "Task.Actions.Exec.Command"
            Expected = $ExpectedXmlDoc.Task.Actions.Exec.Command
            Actual   = $CurrentXmlDoc.Task.Actions.Exec.Command
        }

        Set-Compliance @ActionCommandCompliance -ComplianceList ([ref]$Compliance)
    }

    if ($CurrentXmlDoc.Task.Actions.Exec.Arguments -ne $ExpectedXmlDoc.Task.Actions.Exec.Arguments) {
        $ActionArgsCompliance = @{
            Status   = "Noncompliant"
            Field    = "Task.Actions.Exec.Arguments"
            Expected = $ExpectedXmlDoc.Task.Actions.Exec.Arguments
            Actual   = $CurrentXmlDoc.Task.Actions.Exec.Arguments
        }

        Set-Compliance @ActionArgsCompliance -ComplianceList ([ref]$Compliance)
    }

    <#
    Compare principal settings

    Verify:
    - RunLevel: LeastPrivilege
    - GroupId: S-1-5-4
    #>
    if ($CurrentXmlDoc.Task.Principals.Principal.RunLevel -ne $ExpectedXmlDoc.Task.Principals.Principal.RunLevel) {
        $PrincipalRunLevelCompliance = @{
            Status   = "Noncompliant"
            Field    = "Task.Principals.Principal.RunLevel"
            Expected = $ExpectedXmlDoc.Task.Principals.Principal.RunLevel
            Actual   = $CurrentXmlDoc.Task.Principals.Principal.RunLevel
        }

        Set-Compliance @PrincipalRunLevelCompliance -ComplianceList ([ref]$Compliance)
    }

    if ($CurrentXmlDoc.Task.Principals.Principal.GroupId -ne $ExpectedXmlDoc.Task.Principals.Principal.GroupId) {
        $PrincipalGroupIdCompliance = @{
            Status   = "Noncompliant"
            Field    = "Task.Principals.Principal.GroupId"
            Expected = $ExpectedXmlDoc.Task.Principals.Principal.GroupId
            Actual   = $CurrentXmlDoc.Task.Principals.Principal.GroupId
        }

        Set-Compliance @PrincipalGroupIdCompliance -ComplianceList ([ref]$Compliance)
    }

    <#
    Output noncompliant devices and exit with the appropriate exit code.

    If any noncompliant fields are found, run remediation script to remove and add task again.
    #>
    $Compliance | Where-Object { $PSItem.Status -eq "Noncompliant" } | ForEach-Object {
        $Compliance | Format-List

        Write-Output -InputObject "Scheduled Task [$TaskName] is noncompliant."
        Write-Output -InputObject "Remediation Required: $($Compliance.Count) noncompliant fields found.`n"
        exit 1
    }

    # If the task is compliant, exit 0
    Write-Output -InputObject "`nScheduled Task [$TaskName] is compliant."
    Write-Output -InputObject "No remediation required.`n"
    exit 0
}
catch {
    Write-Error -Message "Error checking task compliance: $($_.Exception.Message)"
    exit 1
}
finally {
    Stop-Transcript
}