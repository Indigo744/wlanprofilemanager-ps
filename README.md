# Description

Automatically switch wlan profiles on Windows using this Powershell script!

Inspired by [xzer/wlanprofilemanager](https://github.com/xzer/wlanprofilemanager) (nodeJS)

# Features

 - Unlimited amount of profiles
 - Set specific IP, Mask and Gateway or reset to auto (DHCP)
 - Set specific DNS or reset to auto
 - Be notified when a profile is applied

# How to use

## Configure

- Download this repository and extract it in a local folder
- Copy the `profiles.sample.psd1` to `profiles.psd1`
- Customize your `profiles.psd1` file: add your own profile using the WiFi network name (SSID)

Now, when you run `wlanprofilemanager.bat` as administrator, the profile will automatically be applied depending on the current network connected to.

Logs can be found in .\logs folder.

## Make it run automatically

### By using the tasks installer

Run as administrator one of the following file:
 - `wlanprofilemanager-install-task-with-notification.bat` in order to install all needed tasks and get a notification when a profile is applied
 - `wlanprofilemanager-install-task-no-notification.bat` in order to install only the mandatory task

### By creating the task manually

Want to handle this yourself? That's fine! Here's how:

- Register a new task in Task Scheduler (Start -> Search for Tasks Scheduler)
    - pick up the wlanprofilemanager.bat as the operation of the task
    - make sure the task will be executed by user "SYSTEM"
    - define the trigger as following:
        - start at: event
        - basic, log: Microsoft-Windows-WLAN-AutoConfig/Operational
        - source: WLAN-AutoConfig
        - event id: 11001

# License

MIT License - see LICENSE file
