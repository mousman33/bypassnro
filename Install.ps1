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
   Param ([string]$logstring, [ConsoleColor]$color = "White")
   $logdate = Get-Date -Format "yy/MM/dd HH:mm:ss"
   Add-content $logfile -value "$($logdate): $logstring"
   Write-Host "$($logdate): $logstring" -ForegroundColor $color
}

write-log "Starting Windows 11 Install Script" -Color Cyan
write-log "This script is to install the required software and configs for the Windows 11 image." -Color Cyan
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

#change power plan to high performance
POWERCFG -SetActive '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
write-log "Power plan set to High Performance" -Color Green
#set dark mode
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name AppsUseLightTheme -Value 0
Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize -Name SystemUsesLightTheme -Value 0
#show hidden files
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "hidden" -Value 1
#show file name extensions
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "hidefileext" -Value 0
Stop-Process -processName: Explorer -force #restarts explorer to show changes

# ask to enable hidden admin shares
$adminshares = read-host "Enable hidden admin shares (Y/N)?"
if ($adminshares -eq "y") {
    New-ItemProperty -Name LocalAccountTokenFilterPolicy -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -PropertyType DWORD -Value 1
    write-log "Hidden admin shares enabled" -Color Green
}


#test for internet connectivity
write-log "Testing internet connectivity" -Color Cyan
$testResult = Test-NetConnection 8.8.8.8
while (-not $testResult.PingSucceeded) {
    write-log "WARNING: Internet connectivity test failed. Please install drivers and connect to internet manually." -Color Yellow
    $internet = read-host "Internet connectivity test failed. Install drivers and connect to internet manually. 'N' to skip. Enter to try again"
    if ($internet -eq "n") { 
        $testResult.PingSucceeded = $true #exit loop if user enters n
    } else {
        write-log "Testing internet connectivity again..." -Color Cyan
        $testResult = Test-NetConnection 8.8.8.8
    }
}

#check Windows activation status
$activation = (Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL").LicenseStatus
if ($activation -eq 1) {
    write-log "Windows is activated." -Color Green
} else {
    write-log "WARNING: Windows is not activated. Attempting activation now." -Color Yellow
    #activate windows with built in OEM key
    $key=(Get-WmiObject -Class SoftwareLicensingService).OA3xOriginalProductKey
    Invoke-Expression "cscript /b C:\windows\system32\slmgr.vbs /upk" #uninstall current product key
    Invoke-Expression "cscript /b C:\windows\system32\slmgr.vbs /ipk $key" #install the OEM key
    Invoke-Expression "cscript /b C:\windows\system32\slmgr.vbs /ato" #activate online
}

#new computer name
write-log "Getting new name" -Color Cyan
$newname = read-host "Enter the new computer name"
write-log "New computer name: $newname" -Color Green
Rename-Computer -NewName $newname -Force

#new computer description
write-log "Getting new description" -Color Cyan
$description = read-host "Enter computer description"
Set-CimInstance -Query 'Select * From Win32_OperatingSystem' -Property @{Description = $description}
write-log "Description set to: $((Get-CimInstance -Query 'Select * From Win32_OperatingSystem').Description)" -Color Green

#set timezone
write-log "Setting timezone" -Color Cyan
$timezone = read-host "Enter timezone (MB, SK, or AB)"
switch ($timezone) {
    "MB" { Set-TimeZone -Id "Central Standard Time" }
    "SK" { Set-TimeZone -Id "Canada Central Standard Time" }
    "AB" { Set-TimeZone -Id "Mountain Standard Time" }
    default { write-log "Invalid timezone selected. Defaulting to Central Standard Time." -Color Yellow ; Set-TimeZone -Id "Central Standard Time" }
} ; write-log "Timezone set to: $((Get-TimeZone).Id)" -Color Green


#run Win11 configs
curl.exe -L "https://raw.githubusercontent.com/mousman33/bypassnro/main/Win11Configs.ps1" -o "C:\temp\Win11Configs.ps1"
write-log "Running Windows 11 configs script" -Color Cyan
. "C:\temp\Win11Configs.ps1"
write-log "Windows 11 configs script completed. Deleting config files..." -Color Green
Remove-Item -Path "C:\temp\Win11Configs.ps1" -Force -ErrorAction SilentlyContinue
Remove-item -path "C:\temp\lib" -recurse -force -ErrorAction SilentlyContinue

# delete the install.ps1 script file
write-log "Running script cleanup" -Color Cyan
write-log "BE SURE TO DELETE C:\temp\Install.ps1 FILE!" -Color Yellow

#open the log file and temp folder
notepad.exe "C:\temp\Win11deploy.log"
explorer.exe "C:\temp"
#open windows update settings
Start-Process ms-settings:windowsupdate
#start windows update
usoclient startscan

pause ; Exit
