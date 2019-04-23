<#
.SYNOPSIS
  Display a notification (balloon/toast) to the user
  
.DESCRIPTION
  This script will display the content of .notify file as a toast to the user.

  In order to work, this script should be run as the current user (and not as SYSTEM or other account).

  Based on https://github.com/proxb/PowerShell_Scripts/blob/master/Invoke-BalloonTip.ps1

.INPUTS
  File .notify

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Indigo744
  Creation Date:  24 april 2019
  Purpose/Change: Initial script release
#>

#---------------------------------------------------------[External Modules]-------------------------------------------------------

Import-Module "./wlanprofilemanager-ps.psm1" -Force

#-----------------------------------------------------------[Execution]------------------------------------------------------------
 
$notification_content = NotifyFileGet
if ($notification_content) {

    # Create a new object
    Add-Type -AssemblyName System.Windows.Forms
    $global:balloon = New-Object System.Windows.Forms.NotifyIcon

    try {

        # Mouse double click on icon to dispose
        [void](Register-ObjectEvent -InputObject $global:balloon -EventName MouseDoubleClick -SourceIdentifier IconClicked -Action {
            $global:balloon.Visible = $false
            $global:balloon.dispose()
            Unregister-Event -SourceIdentifier IconClicked
            Remove-Job -Name IconClicked
            Remove-Variable -Name balloon -Scope Global
        })

        # Need an icon for tray, use process path to get its icon (powershell icon)
        $process_path = Get-Process -id $pid | Select-Object -ExpandProperty Path
        $global:balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($process_path)

        # Set other parameters
        $global:balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
        $global:balloon.BalloonTipText = $notification_content
        $global:balloon.BalloonTipTitle = "wlanprofilemanager"

        # Show the tooltip with a timeout
        $global:balloon.Visible = $true
        $global:balloon.ShowBalloonTip(3000)

        Start-Sleep -Seconds 3
    }
    finally {
        If ($global:balloon) {
            $global:balloon.Visible = $false
            $global:balloon.Dispose()
        }
    }
}
