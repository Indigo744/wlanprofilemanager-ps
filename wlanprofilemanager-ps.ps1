#requires -RunAsAdministrator

<#
.SYNOPSIS
  Automatically switch wlan profiles

.DESCRIPTION
  This script allows you to automatically switch wlan profiles depending on the SSID connected to.

  A profile is a set of IP-related parameters: IP, Gateway, DNS...
  Profiles are defined in profiles.psd1 file.
  You can use profiles.sample.psd1 as a starter.

  This script should be run when the computer connects to a wifi access point.
  The easiest way to do this is to add a scheduled task to trigger at wlan connection.

  This script needs to be run as administrator to be able to modify IP configuration.

  See README.md file for more information on how to install the script on your computer.

.INPUTS
  None

.OUTPUTS
  Log file stored in .\logs

.NOTES
  Version:        1.3
  Author:         Indigo744
  Creation Date:  15 March 2020
  Purpose/Change: Added option "_opt_restart_itf" to choose when the script should restart interface
                  (default is "IfNeeded", which is the same behavior as 1.2)

  Version:        1.2
  Author:         Indigo744
  Creation Date:  27 august 2019
  Purpose/Change: Better DNS IP handling in case of errors
                  Verify configuration at script startup
                  Added non-zero exit code for error
                  Added global catch block

  Version:        1.1
  Author:         Indigo744
  Creation Date:  25 april 2019
  Purpose/Change: Better wlan interface detection
                  Log file cleaning only *.log file

  Version:        1.0
  Author:         Indigo744
  Creation Date:  24 april 2019
  Purpose/Change: Initial script release
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

$DEFAULT_PROFILE = "default_profile"
$AUTO_VALUE = "auto"

#---------------------------------------------------------[External Modules]-------------------------------------------------------

Import-Module "./wlanprofilemanager-ps.psm1" -Force

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Start transcripts
LogTranscriptStart

# Check lock file
if (LockFileExists) {
    Exit 1
}

# Check config file
if (!(ConfigProfilesAvailable)) {
    Exit 2
}

# Read config file
Write-Host "Reading configuration in $PROFILES_FILENAME..."
$config = ConfigProfilesRead
Write-Host " > Found $($config.Count) profiles: $($config.Keys -join ', ')"

# Get options
$optItfRestart = ConfigGetOptionItfRestart $config

# Verify config profiles
if (!(ConfigProfilesVerify $config)) {
    Exit 3
}

# Get WLAN adapter
Write-Host "Checking current wlan connection..."
$wlanAdapter = ItfAutoDetectWLAN
if (!($wlanAdapter)) {
    Write-Error "No wlan interface found, aborting"
    Exit 4
}
$currentItfAlias = $wlanAdapter.InterfaceAlias
$currentItfIndex = $wlanAdapter.InterfaceIndex

# Get current SSID
$currentSSID = GetCurrentSSID
if (!($currentSSID)) {
    Write-Error "No SSID found, aborting"
    Exit 5
}

Write-Host " > Found interface $currentItfAlias ($currentItfIndex) connected on SSID $currentSSID"
ItfPrintIpConfig($currentItfIndex)

# Search for profile in conf
$newProfile = $null
if ($config.ContainsKey($currentSSID)) {
    Write-Host "Applying $currentSSID profile..."
    $profile_applied = $currentSSID
    $newProfile = $config[$currentSSID]
} elseif ($config.ContainsKey($DEFAULT_PROFILE)) {
    Write-Host "Applying *default* profile..."
    $profile_applied = "default"
    $newProfile = $config[$DEFAULT_PROFILE]
} else {
    Write-Error "No corresponding profile nor default profile found, aborting"
    Exit 0
}

$netIpInterface = Get-NetIPInterface -InterfaceIndex $currentItfIndex
$netIPConfiguration = Get-NetIPConfiguration -InterfaceIndex $currentItfIndex
$netIPAddress = Get-NetIPAddress -InterfaceIndex $currentItfIndex

# (netsh wlan show interfaces | select-string SSID | out-string).Trim().Split([Environment]::NewLine)[0].trim().split(":")[1]

# Write lock file
LockFileCreate
try {
    $need_restart = $false
    $has_changed = $false

    # Setting network IP
    if ($newProfile.ip -eq $AUTO_VALUE) {

        if (($netIpInterface.Dhcp) -eq "Enabled") {
            Write-Host " > DHCP already enabled, nothing to do..."
        } else {
            # Activate DHCP on interface, nothing more to do
            Write-Host " > Set DHCP"
            Set-NetIPInterface -InterfaceIndex $currentItfIndex -Dhcp Enabled
            # Reset conf after enabling DHCP
            Write-Host " > Reset conf"
            ItfResetIpConf($currentItfIndex)

            $need_restart = $true
            $has_changed = $true
        }
    } else {
        # Set a static IP address
        $ipAdress = [IPAddress]$newProfile.ip
        $ipAdressGw = [IPAddress]$newProfile.gateway
        $prefixLength = ComputePrefixLengthFromMaskSubnet($newProfile.mask)

        if (($ipAdress -eq $netIPConfiguration.IPv4Address.IPv4Address) -and
            ($ipAdressGw -eq $netIPConfiguration.IPv4DefaultGateway.NextHop) -and
            ($prefixLength -eq $netIPAddress.PrefixLength))
        {
            Write-Host " > Conf already set, nothing to do..."
        } else {
            # Reset conf before adding more IP/Gw
            Write-Host " > Reset conf"
            ItfResetIpConf($currentItfIndex)
            # Set Conf
            Write-Host " > Disable DHCP"
            Set-NetIPInterface -InterfaceIndex $currentItfIndex -Dhcp Disabled
            Write-Host " > Set $ipAdress/$prefixLength (gw $ipAdressGw)"
            New-NetIPAddress –InterfaceIndex $currentItfIndex -AddressFamily IPv4 -IPAddress $ipAdress –PrefixLength $prefixLength -DefaultGateway $ipAdressGw | out-null
            Write-Host " > Done"

            $need_restart = $true
            $has_changed = $true
        }
    }

    # Setting network DNS
    if ($newProfile.dns -eq $AUTO_VALUE) {
        if (ItfCheckIfDnsIsAuto($currentItfIndex)) {
            Write-Host " > DNS already set to auto, nothing to do..."
        } else {
            # Reset DNS on interface, nothing more to do
            Write-Host " > Set automatic DNS"
            Set-DnsClientServerAddress -InterfaceIndex $currentItfIndex -ResetServerAddresses
            Write-Host " > Done"

            $has_changed = $true
        }
    } else {
        # Set static DNS IP addresses
        $ipAdressDns = [IPAddress]$newProfile.dns
        $ipAdressDnsAlt = [IPAddress]$newProfile.dns_alternate

        # Try to get current DNS IP configuration
        try { $currentIpAdressDns = $netIPConfiguration.DNSServer.ServerAddresses[0] }
        catch { $currentIpAdressDns = "none" }

        try { $currentIpAdressDnsAlt = $netIPConfiguration.DNSServer.ServerAddresses[1] }
        catch { $currentIpAdressDnsAlt = "none" }

        if (($ipAdressDns -eq $currentIpAdressDns) -and ($ipAdressDnsAlt -eq $currentIpAdressDnsAlt))
        {
            Write-Host " > DNS already set, nothing to do..."
        } else {
            Write-Host " > Set DNS $ipAdressDns/$ipAdressDnsAlt"
            Set-DnsClientServerAddress -InterfaceIndex $currentItfIndex -ServerAddresses ($ipAdressDns,$ipAdressDnsAlt)
            Write-Host " > Flush DNS"
            Clear-DnsClientCache
            Write-Host " > Done"

            $has_changed = $true
        }
    }

    if ($has_changed) {
        InvokeNotifyTask "Applied profile $profile_applied on $currentItfAlias"
    }

    if ($need_restart -or ($has_changed -and $optItfRestart -eq $OPT_ITFRESTART_ALWAYS)) {
        if ($optItfRestart -ne $OPT_ITFRESTART_NEVER)
        {
            Write-Host " > Restarting interface"
            Restart-NetAdapter -Name $currentItfAlias
            Write-Host " > Done"

            # Wait for interface to be back up
            Write-Host " > Waiting interface.."
            ItfWaitForUpStatus($currentItfIndex)
        } else {
            Write-Host " > Skipping restarting interface"
        }
    } else {
        Write-Host " > Interface does not need to be restarted"
    }

    if ($has_changed) {
        Start-Sleep 1

        # Print config
        ItfPrintIpConfig($currentItfIndex)
    }

    Write-Host ""
    Write-Host "Done."

    LogTranscriptCleanOld
}
catch {
    Write-host -Foreground Red     -Background Black  "Fatal exception during script:"
    Write-Host -Foreground DarkRed -Background Black  $_
    Exit 666
}
finally {
    # Remove lock file
    LockFileRemove
    # Remove notify file
    NotifyFileRemove

    # Stop transcript
    LogTranscriptStop
}

Exit 0