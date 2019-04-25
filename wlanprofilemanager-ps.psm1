

#-------------------------------------------------------[Local constants]----------------------------------------------------------

Set-Variable LOCK_FILEPATH -option ReadOnly -Scope Script -Force -value (Join-Path $PSScriptRoot '.lock')
Set-Variable NOTIFY_FILEPATH -option ReadOnly -Scope Script -Force -value (Join-Path $PSScriptRoot '.notify')
Set-Variable LOG_PATH -option ReadOnly -Scope Script -Force -value (Join-Path $PSScriptRoot 'logs')
Set-Variable LOG_HOURS_TO_KEEP -option ReadOnly -Scope Script -Force -value 2
Set-Variable PROFILES_FILENAME -option ReadOnly -Scope Script -Force -value 'profiles.psd1'
Set-Variable TASK_NOTIFY_PATH -option ReadOnly -Scope Script -Force -value "\wlanprofilemanager"
Set-Variable TASK_NOTIFY_NAME -option ReadOnly -Scope Script -Force -value "wlanprofilemanager-notify"

#--------------------------------------------------------[Local variables]---------------------------------------------------------

Set-Variable currentLogFile -Scope Script -Force -value $null

#-----------------------------------------------------------[Functions]------------------------------------------------------------

<#
.SYNOPSIS
    Starts a log file in .\logs subdirectory with a datetime name.

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function LogTranscriptStart() {

    # Create logs dir if not exists
    If(!(test-path $script:LOG_PATH))
    {
        New-Item -ItemType Directory -Force -Path $script:LOG_PATH
    }

    $formattedDate = Get-Date -format "yyyyMMdd-HH\hmm\mss\s"
    $script:currentLogFile = Join-Path $script:LOG_PATH "$formattedDate.log"
    # Start transcript and print date
    Start-Transcript -path $script:currentLogFile
    Get-Date
    Write-Host ""
}

<#
.SYNOPSIS
    Gets the current log filename

.INPUTS
    None
    
.OUTPUTS
    [string] log filename
#>
Function LogTranscriptGetFilename() {
    $script:currentLogFile
}

<#
.SYNOPSIS
    Remove log file older than a specified amount of hours

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function LogTranscriptCleanOld() {
    # Delete log file older than X hours
    $limit = (Get-Date).AddHours((-1 * $Script:LOG_HOURS_TO_KEEP))
    Get-ChildItem (Join-Path $script:LOG_PATH "*.log") | Where-Object {
        -not $_.PSIsContainer -and $_.CreationTime -lt $limit
    } | Remove-Item
}

<#
.SYNOPSIS
    Stop the logging

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function LogTranscriptStop() {
    # Print date and stop transcript
    Write-Host ""
    Get-Date
    Stop-Transcript
}

<#
.SYNOPSIS
    Check if the lock file exists and has not expired (i.e. older than a minute)

.INPUTS
    None
    
.OUTPUTS
    [bool] $true if exists, $false otherwise
#>
Function LockFileExists() {
    if (Test-Path $script:LOCK_FILEPATH) {
        # Will ignore if older than a minute
        if ((((Get-Date) - (Get-Item $script:LOCK_FILEPATH).CreationTime)) -gt (New-TimeSpan -minutes 1)) {
            Write-Error "Lock file found, but too old. Continuing"
        } else {
            Write-Error "Lock file found, aborting"
            return $true
        }
    }
    return $false
}

<#
.SYNOPSIS
    Create the lock file

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function LockFileCreate() {
    "locked" | Out-File $script:LOCK_FILEPATH 
}

<#
.SYNOPSIS
    Remove the lock file

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function LockFileRemove() {
    Remove-Item $script:LOCK_FILEPATH -Force -confirm:$false 2>&1 | out-null
}

<#
.SYNOPSIS
    Set the content of the notify file
    This file is used for the 'notify' task (passing data from a system process to a user process)

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function NotifyFileSet($content) {
    $content | Out-File $script:NOTIFY_FILEPATH 
}

<#
.SYNOPSIS
    Get the content of the notify file
    This file is used for the 'notify' task (passing data from a system process to a user process)

.INPUTS
    None
    
.OUTPUTS
    [string] file content
#>
Function NotifyFileGet() {
    if (Test-Path $script:NOTIFY_FILEPATH) {
        return Get-Content -Path $script:NOTIFY_FILEPATH
    }
}

<#
.SYNOPSIS
    Remove the notify file
    This file is used for the 'notify' task (passing data from a system process to a user process)

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function NotifyFileRemove() {
    Remove-Item $script:NOTIFY_FILEPATH -Force -confirm:$false 2>&1 | out-null
}

<#
.SYNOPSIS
    Check if the config file containing the profiles is available

.INPUTS
    None
    
.OUTPUTS
    [bool] $true if available, $false otherwise
#>
Function ConfigProfilesAvailable() {
    if (!(Test-Path (Join-Path $PSScriptRoot $script:PROFILES_FILENAME))) {
        Write-Error "No config file found, aborting"
        return $false
    }
    return $true
}

<#
.SYNOPSIS
    Read the config file containing the profiles

.INPUTS
    None
    
.OUTPUTS
    [array] Array of profiles
#>
Function ConfigProfilesRead() {
    return Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName $script:PROFILES_FILENAME
}

<#
.SYNOPSIS
    Auto detect and get the first WLAN interface of this computer
    
.INPUTS
    None
    
.OUTPUTS
    Microsoft.Management.Infrastructure.CimInstance
    Microsoft.Management.Infrastructure.CimInstance#ROOT/StandardCimv2/MSFT_NetAdapter
#>
Function ItfAutoDetectWLAN() {
    return Get-NetAdapter |
        Where-Object { ($_.PhysicalMediaType -eq 'Native 802.11') -or ($_.PhysicalMediaType -eq 'Wireless LAN') -or ($_.PhysicalMediaType -eq 'Wireless WAN') } | 
        Select-Object -first 1
}

<#
.SYNOPSIS
    Print the current IP configuration of an interface

.PARAMETER $itf_index
    Index of the wlan interface to get IP configuration from

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function ItfPrintIpConfig($itf_index) {
    Write-Host (Get-NetIPConfiguration -InterfaceIndex $itf_index | Format-List | Out-String).Trim()
}

<#
.SYNOPSIS
    Wait for an interface to be up (check every second)

.PARAMETER $itf_index
    Index of the wlan interface to wait for

.PARAMETER $timeout_s
    Max amount of time in seconds to wait before throwing a Timeout exception
    Optional, default is $false (no timeout)

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function ItfWaitForUpStatus($itf_index, $timeout_s = $false) {
    $counter = 0
    do {
        Write-Host "." -NoNewline
        Start-Sleep 1
        if ($timeout_s) {
            $counter++
            if ($counter -gt $timeout_s) {
                throw [System.TimeoutException] "Interface $itf_index not up within $timeout_s seconds."
            }
        }
    } while((Get-NetAdapter -InterfaceIndex $itf_index).Status -ne "Up")
    Write-Host "!"
}

<#
.SYNOPSIS
    Reset the IP configuration of an interface

.PARAMETER $itf_index
    Index of the wlan interface to reset

.INPUTS
    None
    
.OUTPUTS
    None
#>
Function ItfResetIpConf($itf_index) {
    # Remove current IP config
    Remove-NetIPAddress -InterfaceIndex $itf_index -confirm:$false 2>&1 | out-null
    # Remove current Gateway config
    Remove-NetRoute -InterfaceIndex $itf_index -confirm:$false 2>&1 | out-null
}

<#
.SYNOPSIS
    Check if DNS of an interface is given by DHCP (auto) or manually set by user

.PARAMETER $itf_index
    Index of the wlan interface to wait for

.INPUTS
    None
    
.OUTPUTS
    [bool] $true if auto, $false otherwise
#>
Function ItfCheckIfDnsIsAuto($itf_index) {
    # https://stackoverflow.com/a/17819465/8861729
    $InterfaceGuid = (Get-NetAdapter -InterfaceIndex $itf_index).InterfaceGuid
    return ((Get-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$InterfaceGuid").NameServer -eq "")
}

<#
.SYNOPSIS
    Get the SSID of the wireless interface

.NOTES
    The SSID could be found using (Get-NetConnectionProfile).Name
    However, this value may be set to "Unindentified Network" when the IP configuration is invalid

    Hence, we can only rely on the "netsh" commandline utility and manual string parsing.

.INPUTS
    None
    
.OUTPUTS
    [string] current SSID
#>
Function GetCurrentSSID() {
    $wlaninterface = netsh wlan show interfaces
    $raw_ssid = ($wlaninterface | select-string SSID | out-string).Trim().Split([Environment]::NewLine)[0].Trim()
    return $raw_ssid.split(":")[1].Trim()
}

<#
.SYNOPSIS
    Compute the prefix length from a mask subnet

.PARAMETER $maskSubnet
    The mask subnet (e.g. 255.255.255.0)

.INPUTS
    None
    
.OUTPUTS
    [int] Prefix length
#>
Function ComputePrefixLengthFromMaskSubnet($maskSubnet) {
    return ([System.Collections.BitArray](([IPAddress]$maskSubnet).GetAddressBytes()) -ne $false ).Count
}

<#
.SYNOPSIS
    Run the notify task to display a message to the current user

.PARAMETER $text
    The message to display to the user

.INPUTS
    None

.OUTPUTS
    None
#>
function InvokeNotifyTask($text)
{
    NotifyFileSet $text
    Start-ScheduledTask -TaskPath $script:TASK_NOTIFY_PATH -TaskName $script:TASK_NOTIFY_NAME -ErrorAction Ignore
}
