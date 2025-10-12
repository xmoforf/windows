@echo off
setlocal enabledelayedexpansion

set "timestamp=%date% %time%"
set "log=%cd%\install.log"


:: This segment specifies where files are coming from.
set "src_oem=%systemdrive%\OEM"
set "src_openssl=https://download.firedaemon.com/FireDaemon-OpenSSL/FireDaemon-OpenSSL-x64-3.6.0.exe"


:: Create download directory
mkdir %src_oem% >nul 2>&1
mkdir %src_oem%\downloads >nul 2>&1


:: Check/Install openssl
echo [*] Check for and install OpenSSL
where openssl > nul 2>&1
if errorlevel 1 (
    echo [!] OpenSSL not found in PATH.
    echo [*] Downloading and installing OpenSSL...
    curl -sSL "%src_openssl%" -o "%src_oem%\downloads\openssl-installer.exe"
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed down download OpenSSL installer.
	goto :eof
    )
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process %src_oem%\downloads\openssl-installer.exe -ArgumentList '/exenoui /exelog fdopenssl3.log /qn /norestart REBOOT=ReallySuppress APPDIR=C:\openssl ADJUSTSYSTEMPATHENV=yes' -Wait"
)


:: Other Packages
echo [*] Extracting other packages...
C:\openssl\bin\openssl enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\blob" -out "%src_oem%\srcfiles.zip" -pass "file:%src_oem%\secret"
C:\openssl\bin\openssl enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\blob2" -out "%src_oem%\install2.bat" -pass "file:%src_oem%\secret"
powershell -NoProfile -Command "Expand-Archive -Path '%src_oem%\srcfiles.zip' -DestinationPath '%src_oem%' -Force"
move "%src_oem%\srcfiles\*" "%src_oem%\downloads" > nul 2>&1
rmdir "%src_oem%\srcfiles" > nul 2>&1
del /Q "%src_oem%\srcfiles.zip" "%src_oem%\blob*" > nul 2>&1

"%src_oem%\install2.bat"

endlocal
