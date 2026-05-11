<#
Uses a bit of the Debloat Windows 10 Scripts from https://github.com/W4RH4WK/Debloat-Windows-10
"THE BEER-WARE LICENSE" (Revision 42):

As long as you retain this notice you can do whatever you want with this
stuff. If we meet some day, and you think this stuff is worth it, you can
buy us a beer in return.

CHANGELOG
Feb 2023 - MB
    GWWin11Configs.ps1 forked from original win10 version
    Default Windows 11 apps - added microsoftteams (built in chat app)
    added "disable built in Teams Chat in win11" to disable chat being added to taskbar
    updated "Setting Default Start Menu Layout" to win11 compatible method
#>

Import-Module -DisableNameChecking $PSScriptRoot\lib\force-mkdir.psm1
Import-Module -DisableNameChecking $PSScriptRoot\lib\take-own.psm1

# Throw caution (to the wind?) - show if NoWarn param is not passed, or passed as $false:
Write-Host "THIS SCRIPT MAKES CONSIDERABLE CHANGES TO THE DEFAULT CONFIGURATION OF WINDOWS AND COULD BE CONSIDERED HASHTAG AGGRESSIVE." -ForegroundColor Yellow
Write-Host ""
Write-Host "This script is provided AS-IS - usage of this source assumes that you are at the very least familiar with PowerShell, and the tools used to create and debug this script." -ForegroundColor Yellow
Write-Host ""
Write-Host "In other words, if you break it, you get to keep the pieces." -ForegroundColor Magenta
Write-Host ""

$ProgressPreference = "SilentlyContinue"
$ErrorActionPreference = "SilentlyContinue"

# // ============
# // Begin Config
# // ============

# Set Computer to High Perf scheme if not a laptop:
Write-Host "Checking if a Computer is a Laptop so it won't aggressively set Power Plan" -ForegroundColor Green
$isLaptop = (Get-WmiObject -Class win32_ComputerSystem).PCSystemType

If($isLaptop -ne 2){
Write-Host ""
Write-Host "Desktop Detected, Setting Computer to High Performance Power Scheme..." -ForegroundColor Green
POWERCFG -SetActive '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
Powercfg /Change monitor-timeout-ac 30
Powercfg /Change standby-timeout-ac 0
# Disable Hard Disk Timeouts:
POWERCFG /SETACVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
POWERCFG /SETDCVALUEINDEX 381b4222-f694-41f0-9685-ff5bb260df2e 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0
# Disable Hibernate
POWERCFG -h off
}
Else{
Write-Host "Laptop Detected, changing sleep settings" -ForegroundColor Green
#ac is when on battery, dc is plugged in 
Powercfg /Change monitor-timeout-ac 30
Powercfg /Change monitor-timeout-dc 15
Powercfg /Change standby-timeout-ac 0
Powercfg /Change standby-timeout-dc 60
# Enable Hibernate
POWERCFG -h on
}

#Base Registry Changes
#Set Registry Changes for the Hidden Admin Share

Write-Host "Enabling Admin Share..." -ForegroundColor Green
New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'LocalAccountTokenFilterPolicy' -PropertyType DWORD -Value '1' | Out-Null

#Block Microsoft Accounts
New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'NoConnectedUse' -PropertyType DWORD -Value '3' | Out-Null

#Enable PowerShell Remoting for Windows Admin Center
Write-Host "Enable PowerShell Remoting for Window Admin Center" -ForegoundColor Green
Enable-PSRemoting -force

#Set Registry Changes for removing Microsoft Tracking

#Disables P2P Windows Updates
New-ItemProperty -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name 'DownloadMode' -PropertyType DWORD -Value '0' | Out-Null
#Disables sending Settings to Cloud
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" -Name 'DisableSettingSync' -PropertyType DWORD -Value '2' | Out-Null
#Disables File Sync to Cloud
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync" -Name 'DisableSettingSyncUserOverride' -PropertyType DWORD -Value '1' | Out-Null
#Disables Ad Customization
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name 'DisabledByGroupPolicy' -PropertyType DWORD -Value '1' | Out-Null
#Disables MS Data Collection and Sending
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name 'AllowTelemetry' -PropertyType DWORD -Value '0' | Out-Null
#disable sending files to encrypted drives
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\EnhancedStorageDevices" -Name 'TCGSecurityActivationDisabled' -PropertyType DWORD -Value '0' | Out-Null
#disable sync files to one drive
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" -Name 'DisableFileSyncNGSC' -PropertyType DWORD -Value '1' | Out-Null
#Disables Certificate Revocation Check
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\safer\codeidentifiers" -Name 'authenticodeenabled' -PropertyType DWORD -Value '0' | Out-Null
#Disables the Sending of Additional Information With Error Reports
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name 'DontSendAdditionalData' -PropertyType DWORD -Value '1' | Out-Null
#Disables Web Search in Search Bar
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name 'DisableWebSearch' -PropertyType DWORD -Value '1' | Out-Null
#Disables Web Search When Searching PC
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name 'ConnectedSearchUseWeb' -PropertyType DWORD -Value '0' | Out-Null
#Disables Location Based Info Sent With Searches
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name 'AllowSearchToUseLocation' -PropertyType DWORD -Value '0' | Out-Null
#Disables Language Detection
New-ItemProperty -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name 'AlwaysUseAutoLangDetection' -PropertyType DWORD -Value '0' | Out-Null
#Disables WiFi Sense
New-ItemProperty -Path "HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" -Name 'AutoConnectAllowedOEM' -PropertyType DWORD -Value '0' | Out-Null
Write-Host "Removing Microsoft Tracking Settings..." -ForegroundColor Green
Write-Host ""
Write-Host ""
    
# Remove (Almost All) Inbox Universal Apps:

# Disable "Consumer Features" (aka downloading apps from the internet automatically)
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\' -Name 'CloudContent' | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableWindowsConsumerFeatures' -PropertyType DWORD -Value '1' | Out-Null
# Disable the "how to use Windows" contextual popups
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' -Name 'DisableSoftLanding' -PropertyType DWORD -Value '1' | Out-Null 
#Disable Automatic Download of "Crapware' apps.
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' -Name 'AutoDownloads' -PropertyType DWORD -Value '2' | Out-Null 
#disable built in Teams Chat in win11
new-item -Path 'HKLM:\software\policies\Microsoft\windows' -Name "Windows Chat"
New-ItemProperty -Path 'HKLM:\software\policies\Microsoft\windows\windows chat' -PropertyType dword -Name "chaticon" -Value 3 -Force

Write-Host "Removing (most) built-in Universal Apps..." -ForegroundColor Yellow
Write-Host ""

    
Write-Host "Elevating privileges for this process" -ForegroundColor Yellow
do {} until (Elevate-Privileges SeTakeOwnershipPrivilege)

Write-Host "Uninstalling default apps" -ForegroundColor Yellow
$apps = @(
    # default Windows 10 apps
    "Microsoft.3DBuilder"
    #"Microsoft.Appconnector"
    "Microsoft.BingFinance"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.XboxGameOverlay"
    "Microsoft.Print3D"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.BingWeather"
    #"Microsoft.FreshPaint"
    "Microsoft.Getstarted"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MixedReality.Portal"
    "Microsoft.Office.OneNote"
    "Microsoft.Office.Desktop"
    #"Microsoft.OneConnect"
    #"Microsoft.People"
    "Microsoft.SkypeApp"
    "Microsoft.RemoteDesktop"
    #"Microsoft.Windows.Photos"
    "Microsoft.WindowsAlarms"
    #"Microsoft.WindowsCalculator"
    "Microsoft.WindowsCamera"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsPhone"
    "Microsoft.WindowsSoundRecorder"
    #"Microsoft.WindowsStore"
    "Microsoft.XboxApp"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.Xbox.TCUI"
    "Microsoft.ZuneMusic"
    "Microsoft.ZuneVideo"
    "microsoft.windowscommunicationsapps"
    "Microsoft.MinecraftUWP"
    "Microsoft.Advertising.Xaml"
    "Microsoft.MSPaint"
    "Microsoft.Windows.HolographicFirstRun"
    "Microsoft.YourPhone"
    # Default Windows 11 apps
    "MicrosoftTeams"
    "MicrosoftWindows.Client.WebExperience"
    "microsoft.outlookforwindows"
    "clipchamp.clipchamp"

    # Threshold 2 apps
    "Microsoft.CommsPhone"
    "Microsoft.ConnectivityStore"
    "Microsoft.Messaging"
    "Microsoft.Office.Sway"
    "Microsoft.OneConnect"
    "Microsoft.WindowsFeedbackHub"


    #Redstone apps
    "Microsoft.BingFoodAndDrink"
    "Microsoft.BingTravel"
    "Microsoft.BingHealthAndFitness"
    "Microsoft.WindowsReadingList"

    # non-Microsoft
    "9E2F88E3.Twitter"
    "PandoraMediaInc.29680B314EFC2"
    "Flipboard.Flipboard"
    "ShazamEntertainmentLtd.Shazam"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushSodaSaga"
    "king.com.*"
    "ClearChannelRadioDigital.iHeartRadio"
    "4DF9E0F8.Netflix"
    "6Wunderkinder.Wunderlist"
    "Drawboard.DrawboardPDF"
    "2FE3CB00.PicsArt-PhotoStudio"
    "D52A8D61.FarmVille2CountryEscape"
    "TuneIn.TuneInRadio"
    "GAMELOFTSA.Asphalt8Airborne"
    "TheNewYorkTimes.NYTCrossword"
    "DB6EA5DB.CyberLinkMediaSuiteEssentials"
    "Facebook.Facebook"
    "flaregamesGmbH.RoyalRevolt2"
    "Playtika.CaesarsSlotsFreeCasino"
    "WinZipComputing.WinZipUniversal"
    "KeeperSecurityInc.Keeper"
    "CAF9E577.Plex"
    "89006A2E.AutodeskSketchBook"
    "64885BlueEdge.OneCalendar"
    "41038Axilesoft.ACGMediaPlayer"
    "2414FC7A.Viber"
    "A278AB0D.MarchofEmpires"
    "828B5831.HiddenCityMysteryofShadows"
    "DellInc.DellPrecisionOptimizer"
    "7EE7776C.LinkedInforWindows"
    "DellInc.DellDigitalDelivery"
    "DellInc.DellSupportAssistforPCs"
    "A278AB0D.DisneyMagicKingdoms"

    # apps which cannot be removed using Remove-AppxPackage
    #"Microsoft.BioEnrollment"
    #"Microsoft.MicrosoftEdge"
    #"Microsoft.Windows.Cortana"
    #"Microsoft.WindowsFeedback"
    #"Microsoft.XboxGameCallableUI"
    #"Microsoft.XboxIdentityProvider"
    #"Windows.ContactSupport"
)

foreach ($app in $apps) {
    Write-Host "Trying to remove $app" -ForegroundColor Green

    Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage

    Get-AppXProvisionedPackage -Online |
        Where-Object DisplayName -EQ $app |
        Remove-AppxProvisionedPackage -Online
}

#Disable App Suggestions for New Users
Write-Host "Editing Default User Profile to Remove Suggestions/App Downloads" -ForegroundColor Green

reg load HKU\Default_User C:\Users\Default\NTUSER.DAT
Set-ItemProperty -Path Registry::HKU\Default_User\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SystemPaneSuggestionsEnabled -Value 0  | Out-Null
Set-ItemProperty -Path Registry::HKU\Default_User\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name PreInstalledAppsEnabled -Value 0  | Out-Null
Set-ItemProperty -Path Registry::HKU\Default_User\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name OemPreInstalledAppsEnabled -Value 0  | Out-Null
Set-ItemProperty -Path Registry::HKU\Default_User\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager -Name SubscribedContent-338388Enabled -Value 0 | Out-Null
New-ItemProperty -Path Registry::HKU\Default_User\SOFTWARE\Microsoft\Windows\CurrentVersion\Search -Name SearchboxTaskbarMode -PropertyType DWORD -Value 0 | Out-Null
New-ItemProperty -Path Registry::HKU\Default_User\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -PropertyType DWORD -Value 1 | Out-Null
New-ItemProperty -Path Registry::HKU\Default_User\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People -Name PeopleBand -PropertyType DWORD -Value 0 | Out-Null

reg unload HKU\Default_User


# Disable Cortana:
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\' -Name 'Windows Search' | Out-Null

Write-Host "Disabling Cortana..." -ForegroundColor Yellow
Write-Host ""
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowCortana' -PropertyType DWORD -Value '0' | Out-Null

#Enable WMI in the Firewall
netsh advfirewall firewall set rule group="windows management instrumentation (wmi)" new enable=yes

# WindowsUpdate Tweaks - Disable Peer Caching and "Updates are Available" Message:
Write-Host "Disabling PeerCaching..." -ForegroundColor Yellow
Write-Host ""
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config' -Name 'DODownloadMode' -Value '0'
Write-Host "Disable 'Updates are available' message" -ForegroundColor Yellow
takeown /F "$env:WinDIR\System32\MusNotification.exe"
icacls "$env:WinDIR\System32\MusNotification.exe" /deny "Everyone:(X)"
takeown /F "$env:WinDIR\System32\MusNotificationUx.exe"
icacls "$env:WinDIR\System32\MusNotificationUx.exe" /deny "Everyone:(X)"

# Increase Service Startup Timeout:
Write-Host "Increasing Service Startup Timeout To 180 Seconds..." -ForegroundColor Yellow
Write-Host ""
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'ServicesPipeTimeout' -Value '180000' | Out-Null


# Disable IE First Run Wizard:
Write-Host "Disabling IE First Run Wizard..." -ForegroundColor Green
Write-Host ""
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft' -Name 'Internet Explorer' | Out-Null
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer' -Name 'Main' | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main' -Name DisableFirstRunCustomize -PropertyType DWORD -Value '1' | Out-Null

# Remove Previous Versions:
Write-Host "Removing Previous Versions Capability..." -ForegroundColor Yellow
Write-Host ""
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'NoPreviousVersionsPage' -Value '1' | Out-Null

# Configure Search Options:
Write-Host "Configuring Search Options..." -ForegroundColor Green
Write-Host ""
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'AllowSearchToUseLocation' -PropertyType DWORD -Value '0' | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name 'ConnectedSearchUseWeb' -PropertyType DWORD -Value '0' | Out-Null

#Setting Default Start Menu Layout
Write-Host "Configuring Start Menu" -ForegroundColor Green
xCopy ".\lib\start2.bin" "c:\users\default\AppData\Local\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\" /y

#Disable the Lock Screen
Write-Host "Removing the Lock Screen" -ForegroundColor Green
New-Item -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows' -Name 'Personalization' | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' -Name 'NoLockScreen' -PropertyType DWORD -Value '1' | Out-Null

#DisableWifiSense
Write-Host "Disabling WiFi Sense" -ForegroundColor Green
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config' -Name 'AutoConnectAllowedOEM' -PropertyType DWORD -Value '0' | Out-Null

# Did this break?:

Write-Host "This script has completed." -ForegroundColor Green
Write-Host ""
Write-Host "Please review output in your console for any indications of failures, and resolve as necessary." -ForegroundColor Yellow
Write-Host ""