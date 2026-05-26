mkdir c:\temp
curl -L https://github.com/mousman33/bypassnro/raw/refs/heads/main/Install.ps1 -o c:\temp\install.ps1
curl -L -o C:\Windows\Panther\unattend.xml https://github.com/mousman33/bypassnro/raw/refs/heads/main/unattend.xml
%WINDIR%\System32\Sysprep\Sysprep.exe /oobe /unattend:C:\Windows\Panther\unattend.xml /reboot
