curl -L -o C:\Windows\Panther\unattend.xml https://github.com/mousman33/bypassnro/raw/refs/heads/main/unattend.xml
%WINDIR%\System32\Sysprep\Sysprep.exe /oobe /unattend:C:\Windows\Panther\unattend.xml /reboot
