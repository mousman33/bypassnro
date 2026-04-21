<#automated script to install the required software and configs for the Windows 11 image

NOTES:
- This script is run from autounattend.xml Windows Setup which writes a log to c:\temp\Win11deploy.log
- This script is intended to be run on a new Windows 11 install.
- It will prompt for the new computer name, description, and timezone.

CHANGELOG:
V26.04.20 - Initial version - MB
    - copied from a previous script I had and modified for the new image.
TODO:
    - add picker for apps to install via winget
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
. "C:\temp\Win11Configs.ps1"
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
