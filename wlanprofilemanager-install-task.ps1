#requires -RunAsAdministrator

<#
.SYNOPSIS
  Install the tasks
  
.DESCRIPTION
  This script will install the following tasks on your system:

   1. \wlanprofilemanager\wlanprofilemanager
      Run when the computer connects to a new network.
      Launches the main scripts to apply the desired wlan profile.

   2. \wlanprofilemanager\wlanprofilemanager-notify
      Run manually by the main script.
      Allows to display a notification to the user when a profile is applied.
      Installed only if -noNotification switch is not present

      This second task is needed because the main script will run as SYSTEM in another session
      which cannot show a notification to the currently logged in user.
      This task run as the connected user, and such can display a message to the user.
  
  This script needs to be run as administrator to be able to set the tasks.

  All tasks templates (XML) can be found in .\tasks subfolder.

.PARAMETER -noNotification
  Switch parameter
  If set, will not install the notification task

.INPUTS
  None

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Indigo744
  Creation Date:  24 april 2019
  Purpose/Change: Initial script release
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

param([switch]$noNotification)

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$tasks_path = Join-Path $PSScriptRoot "tasks"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function RemoveTask($task_name) {
    Unregister-ScheduledTask -TaskName $task_name -Confirm:$false 2>&1 | out-null
}

Function InstallTask($task_name, $filepath) {
    $xml_content = Get-Content $filepath | Out-String
    $xml_content = $xml_content -replace "{{SCRIPTPATH}}",$PSScriptRoot
    
    Register-ScheduledTask -Force -xml $xml_content -TaskPath '\wlanprofilemanager' -TaskName $task_name
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

Write-Host "Removing existing tasks"
RemoveTask 'wlanprofilemanager'
RemoveTask 'wlanprofilemanager-notify'

Write-Host "Installing new tasks"
InstallTask 'wlanprofilemanager' (Join-Path $tasks_path 'wlanprofilemanager-task.tpl.xml')
if (!($noNotification)) {
    InstallTask 'wlanprofilemanager-notify' (Join-Path $tasks_path 'wlanprofilemanager-notify-task.tpl.xml')
}
