@echo off
setlocal enabledelayedexpansion

set "timestamp=%date% %time%"
set "log=%cd%\install.log"


:: This segment specifies where files are coming from.
set "src_oem=%systemdrive%\OEM"
set "src_openssl=https://download.firedaemon.com/FireDaemon-OpenSSL/FireDaemon-OpenSSL-x64-3.6.0.exe"
set "src_python=https://www.python.org/ftp/python/3.14.0/python-3.14.0-amd64.exe"
set "src_calibre=https://calibre-ebook.com/dist/win64" 
set "src_procdump=https://download.sysinternals.com/files/Procdump.zip"
set "src_kindle_70978=https://archive.org/download/kindle-2-7-70978/kindle-2-7-70978.exe"


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
C:\openssl\bin\openssl enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\blob" -out "%src_oem%\srcfiles.zip" -pass pass:gzQzVTqHUxVrSEkxFHRrAQMn
powershell -NoProfile -Command "Expand-Archive -Path '%src_oem%\srcfiles.zip' -DestinationPath '%src_oem%' -Force"
move "%src_oem%\srcfiles\*" "%src_oem%\downloads" > nul 2>&1
rmdir "%src_oem%\srcfiles" > nul 2>&1
del /Q "%src_oem%\srcfiles.zip" "%src_oem%\blob" > nul 2>&1


:: Check/Install Python
echo [*] Check for and install Python
where python > nul 2>&1
if errorlevel 1 (
    echo [!] Python not found in PATH.
    echo [*] Downloading and installing Python...
    
    curl -sSL "%src_python%" -o %src_oem%\downloads\python-installer.exe
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to download Python installer.
        goto :eof
    )
    
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process %src_oem%\downloads\python-installer.exe -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1' -Wait"
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to install Python.
        goto :eof
    )
)


:: Check/install Calibre
echo [*] Check for and install Calibre
where calibre >nul 2>&1
if errorlevel 1 (
    echo [!] Calibre not found in PATH.
    echo [*] Downloading Calibre...
    
    curl -sSL "%src_calibre%" -o %src_oem%\downloads\calibre-64bit.msi
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to download Calibre installer.
        goto :eof
    )

    echo [*] Installing Calibre...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process msiexec.exe -ArgumentList '/i \"%src_oem%\downloads\calibre-64bit.msi\" /qn' -Wait"
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to install Calibre.
        goto :eof
    )
    
    echo [*] Installing Calibre Plugins...
    "%ProgramFiles%\Calibre2\calibre-customize" -a %src_oem%\downloads\DeDRM_plugin.zip
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to install Calibre plugin: DeDRM.
        goto :eof
    )

    echo [*] Resetting DeDRM Configuration...
    copy /Y "%src_oem%\downloads\dedrm.json" "%userprofile%\AppData\Roaming\calibre\plugins\dedrm.json" > nul 2>&1

    "%ProgramFiles%\Calibre2\calibre-customize" -a %src_oem%\downloads\kfx-input.zip
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to install Calibre plugin: kfx-input.
        goto :eof
    )
    
    "%ProgramFiles%\Calibre2\calibre-customize" -a %src_oem%\downloads\kfx-output.zip
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to install Calibre plugin: kfx-output.
        goto :eof
    )
)
    

:: Check/install procdump
echo [*] Check for and install procdump...
where procdump >nul 2>&1
if errorlevel 1 (
    echo [!] procdump not found in PATH.
    echo [*] Downloading procdump...
    
    curl -sSL "%src_procdump%" -o "%src_oem%\downloads\Procdump.zip"
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to download procdump.
        goto :eof
    )
    
    powershell -NoProfile -Command "Expand-Archive -Path '%src_oem%\downloads\Procdump.zip' -DestinationPath '%src_oem%\downloads' -Force"
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to expand procdump archive.
        goto :eof
    )
    
    copy %src_oem%\downloads\procdump* %SystemRoot%
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to install procdump.
        goto :eof
    )
)


:: Install Kindle for PC no matter what.
echo [*] Install Kindle for PC Version 2.7-70978...
echo [*] Downloading Kindle for PC...
curl -sSL "%src_kindle_70978%" -o "%src_oem%\downloads\kindle-installer.exe"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to download Kindle for PC installer.
    goto :eof
)

echo [*] Disabling Ethernet
netsh interface set interface "Ethernet" admin=disable
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to disable Ethernet interface.
    goto :eof
)

echo [*] Installing Kindle for PC...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process %src_oem%\downloads\kindle-installer.exe -ArgumentList '/S /allusers' -Wait"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to install Kindle for PC.
    goto :eof
)

echo [*] Disabling auto-updates...
powershell -NoProfile -Command "Set-ItemProperty -Path 'HKCU:\SOFTWARE\Amazon\Kindle\User Settings' -Name 'autoUpdate' -Value 'false'"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to disable auto updates for Kindle for PC.
)

echo [*] Disabling crash reporting...
powershell -NoProfile -Command "Set-ItemProperty -Path 'HKCU:\SOFTWARE\Amazon\Kindle\User Settings' -Name 'SendCrashReports' -Value 0"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to disable crash reports for Kindle for PC.
)

echo [*] Re-enabling Ethernet...
netsh interface set interface "Ethernet" admin=enable
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to re-enable Ethernet interface.
    goto :eof
)


:: Install the Key Extractor software
:: Note: This could be modified to build it from source if desired but VSCode needed.
echo [*] Install KRFKeyExtractor...
copy /Y "%src_oem%\downloads\KRFKeyExtractor.exe" "%ProgramFiles(x86)%\Amazon\Kindle" > nul 2>&1
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to copy KRFKeyExtractor.
)

echo [*] Install KFXKeyExtractor28... [unused]
copy /Y "%src_oem%\downloads\KFXKeyExtractor28.exe" "%ProgramFiles(x86)%\Amazon\Kindle" > nul 2>&1
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to copy KRFKeyExtractor.
)


:: Install Launch Scripts...
echo [*] Download and Install Launch Scripts...

mkdir "%src_oem%\batch" > nul 2>&1
del /Q "%src_oem%\batch\*" > nul 2>&1

copy /Y "%src_oem%\downloads\launch_kindle.bat" "%src_oem%\batch\launch_kindle.bat" > nul 2>&1
copy /Y "%src_oem%\downloads\remove_drm.bat"    "%src_oem%\batch\remove_drm.bat" > nul 2>&1
copy /Y "%src_oem%\batch\*.bat" "%ProgramFiles(x86)%\Amazon\Kindle" > nul 2>&1
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to copy launch scripts.
)


:: Install Desktop Icons...
echo [*] Download and Install Desktop Icons...

mkdir "%src_oem%\desktop" > nul 2>&1
del /Q "%src_oem%\desktop\*" > nul 2>&1

copy /Y "%src_oem%\downloads\Disable Ethernet.bat" "%src_oem%\desktop\Disable Ethernet.bat" > nul 2>&1
copy /Y "%src_oem%\downloads\Enable Ethernet.bat"  "%src_oem%\desktop\Enable Ethernet.bat" > nul 2>&1
copy /Y "%src_oem%\downloads\Extract Keys (After Download).lnk" "%src_oem%\desktop\Extract Keys (After Download).lnk" > nul 2>&1
copy /Y "%src_oem%\downloads\Kindle (Wrapped).lnk" "%src_oem%\desktop\Kindle (Wrapped).lnk" > nul 2>&1
copy /Y "%src_oem%\desktop\*" "%public%\Desktop" > nul 2>&1
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to copy desktop icons.
)

echo [*] Removing Default Kindle.lnk
del /Q "%userprofile%\Desktop\Kindle.lnk" > nul 2>&1
del /Q "%public%\Desktop\Kindle.lnk" > nul 2>&1

:: Remove Hosts Override
copy /Q "%src_oem%\hosts.backup" "%SystemRoot%\System32\drivers\etc\hosts" > nul 2>&1
if not errorlevel 1 (
    del /Q "%src_oem%\hosts.backup"
)

endlocal
