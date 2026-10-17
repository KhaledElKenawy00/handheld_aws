@echo off
chcp 65001 >nul
title SANAD Setup

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo [Error] Please Run as administrator!
  pause
  exit /b 1
)

echo ==============================================
echo  SANAD - Network Share Setup
echo ==============================================
echo.

set "USER_PASS=admin123"
set /p "USER_PASS=Enter password for sanad (Press Enter for admin123): "

net user sanad %USER_PASS% /add >nul 2>&1
net user sanad %USER_PASS% >nul 2>&1
net user sanad /expires:never >nul 2>&1

set "TARGET=%~dp0sanad"
if not exist "%TARGET%" mkdir "%TARGET%"
icacls "%TARGET%" /grant sanad:(OI)(CI)F >nul

net share sanad /delete /y >nul 2>&1
net share sanad="%TARGET%" /GRANT:sanad,FULL >nul 2>&1

netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes >nul 2>&1

for /f "tokens=*" %%i in ('powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -like '192.168.*' -or $_.IPAddress -like '10.*'} | Select-Object -First 1).IPAddress"') do set "MY_IP=%%i"

echo.
echo ==============================================
echo  Handheld Settings:
echo ----------------------------------------------
echo  IP       : %MY_IP%
echo  Share    : sanad
echo  User     : sanad
echo  Password : %USER_PASS%
echo  Folder   : %TARGET%
echo ==============================================
echo.
pause
