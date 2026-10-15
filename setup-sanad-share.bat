@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
title SANAD - Network Share Setup
echo ==============================================
echo  SANAD - تجهيز مشاركة الشبكة لاستقبال الملفات
echo ==============================================
echo.

REM --- 1) لازم يتشغل كمسؤول ---
net session >nul 2>&1
if %errorlevel% neq 0 (
  echo [خطأ] كليك يمين على الملف واختار Run as administrator
  pause
  exit /b 1
)
echo [1/6] يعمل بصلاحية المسؤول: تمام

REM --- 2) يوزر المشاركة sanad بالباسورد الثابت admin123 ---
net user sanad admin123 /add >nul 2>&1
net user sanad admin123 >nul 2>&1
net user sanad /expires:never >nul 2>&1
echo [2/6] اليوزر sanad بالباسورد admin123: تمام

REM --- 3) الفولدر جنب مكان السكريبت ---
set "TARGET=%~dp0sanad"
if not exist "%TARGET%" mkdir "%TARGET%"
icacls "%TARGET%" /grant sanad:(OI)(CI)F >nul
echo [3/6] الفولدر: %TARGET%

REM --- 4) المشاركة باسم sanad بصلاحية كاملة ---
net share sanad /delete /y >nul 2>&1
net share sanad="%TARGET%" /GRANT:sanad,FULL >nul 2>&1
if %errorlevel% neq 0 (
  echo [خطأ] فشل إنشاء المشاركة
  pause
  exit /b 1
)
echo [4/6] المشاركة \\%COMPUTERNAME%\sanad: تمام

REM --- 5) فتح جدار الحماية للمشاركة ---
netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes >nul 2>&1
echo [5/6] جدار الحماية: تمام

REM --- 6) IP الجهاز على الشبكة ---
set "IP="
for /f %%a in ('powershell -noprofile -command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -like '192.168.*'} | Select-Object -First 1).IPAddress"') do set "IP=%%a"
if "!IP!"=="" for /f %%a in ('powershell -noprofile -command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1'} | Select-Object -First 1).IPAddress"') do set "IP=%%a"
echo [6/6] IP الجهاز: !IP!
echo.
echo ==============================================
echo  دخل البيانات دي في الهاند هيلد:
echo  (الاعدادات - الارسال للكمبيوتر)
echo ----------------------------------------------
echo  IP الكمبيوتر  : !IP!
echo  اسم المشاركة  : sanad
echo  اليوزر        : sanad
echo  الباسورد      : admin123
echo  مجلد فرعي     : (فاضي)
echo ==============================================
echo  الفولدر اللي هتنزل فيه الملفات:
echo  %TARGET%
echo ==============================================
pause
