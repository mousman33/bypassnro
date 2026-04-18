<#automated script to install the required software and configs for the Windows 11 image

NOTES:
- This script is run from autounattend.xml Windows Setup which writes a log to c:\temp\Win11deploy.log
- This script is intended to be run on a new Windows 11 install.
- It will prompt for the new computer name, description, and timezone.
- This script runs in two parts. The first part runs during initial setup. The second part runs after the computer reboots. 

CHANGELOG:
V25.06.01 - Initial version - MB
V26.01.26 - Initial version - MB
    - split from original Install.ps1 into two parts
        - started new script files to be split in two and use runonce reg key to run second part after restart. 
    - added runonce reg key to run part 2 after restart
    - added auto login for local admin on next login
V26.01.27 - MB
    - edited auto login registry keys for error handling and added reg.exe method because the powershell method wasnt working
V26.01.29 - MB
    - added registry flush to disk to ensure autologon settings persist on first boot
    - removed the reg.exe method of setting autologin since powershell method wasn't the issue
V26-02-02 - MB
    - changed restart command at end of script to ensure immediate restart without delay
    - removed registry flush for autologon since it wasn't the issue
    - added additional autologon registry keys for AutoLogonCount and ForceAutoLogon, and ensure admin account is usable for autologon
V26-02-20 - MB
    - reworked the domain join section to optionally allow manual entry of DC if not reachable, before attempting to join domain or rename computer

TODO:

#>

#start custom log file
Function write-log {
   Param ([string]$logstring)
   $logdate = Get-Date -Format "yy/MM/dd HH:mm:ss"
   Add-content "C:\temp\Win11deploy.log" -value "$($logdate): $logstring"
   Write-Host "$($logdate): $logstring"
}

write-log "Starting Windows 11 Install Script part 1"
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


#get subdomain from ip address, test connection to domain controller, and join domain if reachable
function Join-Domain {
    write-log "Domain Controller is reachable"
    if ((Read-Host "Join the domain? (Y/N)").ToLower() -eq "y") {
        Add-Computer -DomainName "gw.local" -NewName $newname -ErrorVariable err
        if ($err) { write-log $err }
        write-log "Attempted to join the domain. Restart required."
    } else {
        write-log "Skipping domain join. Renaming computer only."
        Rename-Computer -NewName $newname -Force -ErrorVariable err
        if ($err) { write-log $err }
    }
}
# Get local subnet
$IP = (Get-NetIPAddress |
       Where-Object { $_.IPAddress -like "192.168.*" } |
       Select-Object -First 1 -ExpandProperty IPAddress)
$SD = ($IP -split "\.")[2]
$DC  = "192.168.$SD.56"
write-log "Pinging Domain Controller at $DC"
$reachable = (Test-NetConnection $DC).PingSucceeded
# If not reachable, optionally allow manual DC entry
if (-not $reachable -and
    (Read-Host "DC not reachable. Specify another? (Y/N)").ToLower() -eq "y") {
    $DC = Read-Host "Enter full DC IP"
    $reachable = (Test-NetConnection $DC).PingSucceeded
}
if ($reachable) {
    Join-Domain
} else {
    write-log "Domain Controller is not reachable. Renaming computer only."
    Rename-Computer -NewName $newname -Force -ErrorVariable err
    if ($err) { write-log $err }
}

# Ensure Administrator is usable
net user Administrator /logonpasswordchg:no
wmic useraccount where name='Administrator' set PasswordExpires=FALSE
# add registry keys to auto sign in as local admin on next login
write-log "Setting up auto login for local admin on next login"
$regpath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
Set-ItemProperty -Path $regpath -Name "AutoAdminLogon" -Value "1" -force -ErrorVariable aalerr
if ($aalerr) { write-log $aalerr }
Set-ItemProperty -Path $regpath -Name "defaultdomainname" -Value "." -force -ErrorVariable ddnerr
if ($ddnerr) { write-log $ddnerr }
Set-ItemProperty -Path $regpath -Name "DefaultUsername" -Value "administrator" -force -ErrorVariable dunerr
if ($dunerr) { write-log $dunerr }
Set-ItemProperty -Path $regpath -Name "DefaultPassword" -Value "Changem3" -force -ErrorVariable dpwerr
if ($dpwerr) { write-log $dpwerr }
Set-ItemProperty -Path $regpath -Name "AutoLogonCount" -Value 1 -force -ErrorVariable alcerr
if ($alcerr) { write-log $alcerr }
Set-ItemProperty -Path $regpath -Name "ForceAutoLogon" -Value 1 -force -ErrorVariable falerr
if ($falerr) { write-log $falerr }
# Get-ItemProperty -path $regpath | Select-Object AutoAdminLogon,defaultdomainname,DefaultUsername,DefaultPassword,AutoLogonCount,ForceAutoLogon

#setup runonce to run part 2 after restart
write-log "Setting up RunOnce registry key to run part 2 script after restart."
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" -Name "Win11InstallPart2" -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Normal -File `"C:\temp\Installpt2.ps1`""
#prompt for restart
write-log "Part 1 script complete. Restarting the computer to continue with part 2."
read-host "Press enter to restart the computer and continue with part 2 of the installation."
shutdown /r /t 0 /f # r=restart, t=0 seconds, f=force close apps

