<#automated script to install the required software and configs for the Windows 11 image

NOTES:
- This script is run from autounattend.xml Windows Setup which writes a log to c:\temp\Win11deploy.log
- This script is intended to be run on a new Windows 11 install.
- It will prompt for the new computer name, description, and timezone.

CHANGELOG:
V25.06.01 - Initial version - MB
V25.06.02 - MB
    - Added subdomain detection and domain join if DC is reachable
    - added check for Sentinel One and MEDiC services running and delete installer file if so
    - added automatic deletion of Win11 config files and install.ps1 script file
V25.07.22 - MB
    - added change to high performance power plan first
    - changed versioning style to yy.mm.dd
V25.08.08 - MB
    - added write-log line to DELETE install.ps1 file
    - added notepad.exe "C:\temp\Win11deploy.log" to open log file when done.
    - looked into encrypting S1 site token with "convertto-securestring -key". Decided against as risk is minimal and it doesnt add all that much security.
V25.09.10 - MB
    - added internet connection check at start of script
    - added driver install logic if no internet connection and loop until internet is connected
V25.09.11 - MB
    - updated the internet connection logic to allow user to exit loop if they cant get internet
V25.09.16 - MB
    - added usoclient startscan to start windows update at end of script
    - removed the process to delete install.ps1 as it was not working
    - changed autounattend.xml to write log to Win11deploy-v.log
    - created a custom log function (write-log) to write to the log file and console
V25.09.17 - MB
    - wrapped S1 and MEDiC installs in functions
    - only install MEDiC if internet connection is available
V25.10.10 - MB
    - added error capture and logging to driver install, domain join, new PC name, S1 install, and MEDiC install UNTESTED
V25.11.20 - MB
    - fixed error in writing $err message in Domain join, S1, and MEDiC installs
V26.01.26 - MB
    - added check for windows activation status and attempt to activate with OEM key if not activated
    - started new script files to be split in two and use runonce reg key to run second part after restart. 

TODO:
- add more error handling for the script in general
#>

#start custom log file
$logfile = "C:\temp\Win11deploy.log"
Function write-log {
   Param ([string]$logstring)
   $logdate = Get-Date -Format "yy/MM/dd HH:mm:ss"
   Add-content $logfile -value "$($logdate): $logstring"
   Write-Host "$($logdate): $logstring"
}

write-log "Starting Windows 11 Install Script"
write-log "This script is to install the required software and configs for the Windows 11 image."
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#change power plan to high performance
POWERCFG -SetActive '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
write-log "Power plan set to High Performance"


#test for internet connectivity
write-log "Testing internet connectivity"
$testResult = Test-NetConnection 8.8.8.8
if ($testResult.PingSucceeded) {
    write-log "Internet connectivity test passed first try."
} else { 
    write-log "Internet connectivity test failed. Attempting to install drivers and test again."
    #grab model name
    $model = (Get-CimInstance -ClassName Win32_ComputerSystem).Model
    write-log "Model: $model"
    #compare to Drivers folder and install drivers if found
    $driverpath = "C:\temp\Drivers\$model"
    if (Test-Path $driverpath) {
        write-log "Driver folder found: $driverpath. Installing drivers..."
        foreach ($file in Get-ChildItem -Path $driverpath) {
            write-log "Installing driver: $($file.FullName)"
            Start-Process -FilePath $file.FullName -ArgumentList "/s" -Wait -ErrorVariable err
            if ($err) {write-log $err}
        }
        write-log "Drivers attempted install. Testing internet connectivity again..."
    } else {
        write-log "No driver folder found for model: $model. Skipping driver installation."
    }
    #test internet again
    $testResult = Test-NetConnection 8.8.8.8
    while (-not $testResult.PingSucceeded) {
        write-log "WARNING: Internet connectivity test failed. Please install drivers and connect to internet manually."
        $internet = read-host "Internet connectivity test failed. Install drivers and connect to internet manually. 'N' to skip. Enter to try again"
        if ($internet -eq "n") { 
            $testResult.PingSucceeded = $true #exit loop if user enters n
        } else {
            write-log "Testing internet connectivity again..."
            $testResult = Test-NetConnection 8.8.8.8
        }
    }
}

#check Windows activation status
$activation = (Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL").LicenseStatus
if ($activation -eq 1) {
    write-log "Windows is activated."
} else {
    write-log "WARNING: Windows is not activated. Attempting activation now."
    #activate windows with built in OEM key
    $key=(Get-WmiObject -Class SoftwareLicensingService).OA3xOriginalProductKey
    Invoke-Expression "cscript /b C:\windows\system32\slmgr.vbs /upk" #uninstall current product key
    Invoke-Expression "cscript /b C:\windows\system32\slmgr.vbs /ipk $key" #install the OEM key
    Invoke-Expression "cscript /b C:\windows\system32\slmgr.vbs /ato" #activate online
}

#new computer name
write-log "Getting new name"
$newname = read-host "Enter the new computer name"
write-log "New computer name: $newname"

#new computer description
write-log "Getting new description"
$description = read-host "Enter computer description"
Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = $description}
write-log "Description set to: $((Get-CimInstance -Query 'Select * From Win32_OperatingSystem').Description)"

#set timezone
write-log "Setting timezone"
$timezone = read-host "Enter timezone (MB, SK, or AB)"
switch ($timezone) {
    "MB" { Set-TimeZone -Id "Central Standard Time" }
    "SK" { Set-TimeZone -Id "Canada Central Standard Time" }
    "AB" { Set-TimeZone -Id "Mountain Standard Time" }
    default { write-log "Invalid timezone selected. Defaulting to Central Standard Time." ; Set-TimeZone -Id "Central Standard Time" }
} ; write-log "Timezone set to: $((Get-TimeZone).Id)"


#run Win11 configs
write-log "Running Windows 11 configs script"
. "C:\temp\GWWin11Configs.ps1"
write-log "Windows 11 configs script completed. Deleting config files..."
Remove-Item -Path "C:\temp\GWWin11Configs.ps1" -Force -ErrorAction SilentlyContinue
Remove-item -path "C:\temp\lib" -recurse -force -ErrorAction SilentlyContinue

# delete the install.ps1 script file
write-log "Running script cleanup"
write-log "BE SURE TO DELETE C:\temp\Install.ps1 FILE!"

#open the log file and temp folder
notepad.exe "C:\temp\Win11deploy.log"
explorer.exe "C:\temp"
#open windows update settings
Start-Process ms-settings:windowsupdate
#start windows update
usoclient startscan
