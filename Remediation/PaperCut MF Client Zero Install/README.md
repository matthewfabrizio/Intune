# PaperCut MF Client Zero Install

## Summary

These remediation scripts will install the PaperCut MF Client tool via the zero-install method according to [PaperCut's website](https://www.papercut.com/help/manuals/ng-mf/clienttool/user-client-install-windows/#:~:text=The%20recommended%20approach%20with%20Windows%20networks%20is%20the,share%20-%20a%20share%20set%20up%20during%20installation.).

Their documentation recommends launching `pc-client-local-cache.exe`, but this caused error messages on the clients on startup. Switching to `pc-client.exe` was more reliable with no error messages.

## Script Setup

There are a few portions of the script that are specific to a company. The following variables need to be adjusted to fit your needs:

| Script | Variable
| --- | --- |
| Detect | $CompanyName |
| Detect | $PrintServer |
| Set | $CompanyName |
| Set | $PrintServer |
| Remove | $CompanyName |

### Other Variable Notes

`$CompanyName` sets the log directory at `C:\ProgramData`.

`$PrintServer` can either be an IP or hostname of where the client executable is stored.

`$TaskName` should be configured once and not modified afterwards. Changing the name will cause duplicates to be made when the remediation runs.

`$Description` can be adjusted to fit your company needs, but is fairly generic.

## Scheduled Task Detection

The detection script does not validate every property of the scheduled task. The built-in PowerShell cmdlets do not return all details of the task like the xml does. Therefore, the detection script checks a known working xml file and then exports what it finds on the endpoints for comparison.

If `$Description`, `$PrintServer`, `$ExecutablePath`, or `$ExecutableArguments` is modified in the detection and set scripts and then reuploaded into the remediation package, it will modify the current task on the system and make no duplicate tasks.

## Scheduled Task Creation/Update

As long as the detection and set scripts look fairly similar in terms of variables, it will dynamically modify the task whenever you reupload the script package and the remediation runs. 

## Scheduled Task Removal

Task removal has to be setup as a different remediation script package within Intune.

If you need to remove the scheduled task, you need to update the detection script and set `$Removal = $true`. This tells the script to look for a different task name, which triggers the remediation script to remove the task.
