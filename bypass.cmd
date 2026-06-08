@echo off
:: ========================================================================================
:: BypassNRO - A simple script to bypass the OOBE and automate first time setup on Windows 11.
:: NOTE: Running 'sysprep.exe /oobe' without '/generalize' preserves OEM drivers, but it
:: skips the XML 'specialize' pass and thus the scripts that run during that phase.
:: WORKAROUND: This script pre-downloads install.ps1 and inserts the regedit to run it 
:: after sysprep and first logon.
:: ========================================================================================


mkdir c:\temp
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "BypassNRO" /t REG_SZ /d "powershell -ExecutionPolicy Bypass -File C:\temp\install.ps1" /f
curl -L https://github.com/mousman33/bypassnro/raw/refs/heads/main/Install.ps1 -o c:\temp\install.ps1
curl -L -o C:\Windows\Panther\unattend.xml https://github.com/mousman33/bypassnro/raw/refs/heads/main/unattend.xml
%WINDIR%\System32\Sysprep\Sysprep.exe /oobe /unattend:C:\Windows\Panther\unattend.xml /reboot
