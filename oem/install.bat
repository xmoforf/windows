@echo off
setlocal enabledelayedexpansion

set "timestamp=%date% %time%"
set "log=%cd%\install.log"

:: This segment specifies where files are coming from.
set "src_oem=%systemdrive%\OEM"
set "src_python=https://www.python.org/ftp/python/3.14.0/python-3.14.0-amd64.exe"
set "src_calibre=https://calibre-ebook.com/dist/win64" 
set "src_calibre_kfxinput=https://plugins.calibre-ebook.com/291290.zip"
set "src_calibre_kfxoutput=https://plugins.calibre-ebook.com/272407.zip"
set "src_procdump=https://download.sysinternals.com/files/Procdump.zip"
set "src_kindle_70978=https://archive.org/download/kindle-2-7-70978/kindle-2-7-70978.exe"
set "src_keyextractor=https://github.com/user-attachments/files/20700841/KRFKeyExtractor.zip"

:: These come from a self-hosted GitHub where I have build tools from source and have a few
:: .lnk and .bat files to make things look nicer on the Desktop.
set "src_dedrm_git=https://git.xmof.duckdns.org/?p=DeDRM.git"

set "src_extract_krf=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/src/KRFKeyExtractor.exe;h=a9cd57f29dd2ae2f749307e5ebabec3841507719;hb=refs/heads/satsuoni-lcp"
set "src_extract_kfx28=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/src/KFXKeyExtractor28.exe;h=b8a36bf1fc65403977941e73485f8b8ebc7a1a22;hb=refs/heads/satsuoni-lcp"
set "src_calibre_dedrm=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/src/DeDRM_plugin.zip;h=6b133dd44855b1781ce7eea9b8afe3fbbbf8717b;hb=refs/heads/satsuoni-lcp"
set "src_calibre_dedrm_json=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/src/dedrm.json;h=413bbde84673277e8f322c60bf3ce346f296e9de;hb=refs/heads/satsuoni-lcp"
set "src_desktop_disable_ethernet=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/desktop/Disable+Ethernet.bat;h=f17dce949d4627afd6a8d486a6ade576c840b6bc;hb=refs/heads/satsuoni-lcp"
set "src_desktop_enable_ethernet=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/desktop/Enable+Ethernet.bat;h=1407bbdd800bfd0f039e1548a67ea3ab35fce1b3;hb=refs/heads/satsuoni-lcp"
set "src_desktop_extract_keys=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/desktop/Extract+Keys+(After+Download).lnk;h=4e25fb84241484e6923a3ccc57e08b12eae41901;hb=refs/heads/satsuoni-lcp"
set "src_desktop_kindle_wrapped=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/desktop/Kindle+(Wrapped).lnk;h=e3a1ee9f7a5134fdcc983e473420b79fd845bc3d;hb=refs/heads/satsuoni-lcp"
set "src_launch_kindle=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/batch/launch_kindle.bat;h=7eb20234f69f5ed950622446831f8cfe57a9bbbc;hb=refs/heads/satsuoni-lcp"
set "src_remove_drm=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/batch/remove_drm.bat;h=181b7c12c8351f48f6f0b936dafbc0936eb0ab75;hb=refs/heads/satsuoni-lcp"

:: Create download directory
mkdir %src_oem% >nul 2>&1
mkdir %src_oem%\downloads >nul 2>&1


:: Flaky DNS Override
echo [*] Override flaky duckdns.org
if not exist "%src_oem%\hosts.backup" (
    copy "%SystemRoot%\System32\drivers\etc\hosts" "%src_oem%\hosts.backup"
)
echo 5.2.75.153 git.xmof.duckdns.org >> %SystemRoot%\System32\drivers\etc\hosts


:: Check/Install Python
echo [*] Check for and install Python
where python >nul 2>&1
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

    echo [*] Downloading Calibre Plugins...
    echo [*] Plugin: kfx-input    
    curl -sSL "%src_calibre_kfxinput%" -o %src_oem%\downloads\kfx-input.zip
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to download Calibre plugin: kfx-input.
        goto :eof
    )
    
    echo [*] Plugin: kfx-output
    curl -sSL "%src_calibre_kfxoutput%" -o %src_oem%\downloads\kfx-output.zip
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to download Calibre plugin: kfx-output.
        goto :eof
    )
    
    echo [*] Plugin: DeDRM   
    curl -sSL "%src_calibre_dedrm%" -o %src_oem%\downloads\DeDRM_plugin.zip
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to download Calibre plugin: DeDRM.
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

    echo [*] Downloading default DeDRM config...
    curl -sSL "%src_calibre_dedrm_json%" -o "%src_oem%\downloads\dedrm.json" 
    if errorlevel 1 (
        >>"%log%" echo [%timestamp%] [ERROR] Failed to download default DeDRM config.
    )

    echo [*] Resetting DeDRM Configuration...
    copy "%src_oem%\downloads\dedrm.json" "%userprofile%\AppData\Roaming\calibre\plugins\dedrm.json" > nul 2>&1

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

echo [*] Downloading KRFKeyExtractor...
curl -sSL "%src_extract_krf%" -o "%src_oem%\downloads\KRFKeyExtractor.exe"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to download KRFKeyExtractor.
    goto :eof
)

echo [*] Downloading KFXExtractor28...
curl -sSL "%src_extract_kfx28%" -o "%src_oem%\downloads\KFXKeyExtractor28.exe"
if errorlevel 1 (
    >>"%log%" echo [%timestamp] [ERROR] Failed to download KFXKeyExtractor28.
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

:: powershell -NoProfile -Command "Expand-Archive -Path '%src_oem%\Downloads\KRFKeyExtractor.zip' -DestinationPath '%src_oem%\downloads' -Force"
:: if errorlevel 1 (
::     >>"%log%" echo [%timestamp%] [ERROR] Failed to extract KRFKeyExtractor.
:: )

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

curl -sSL "%src_launch_kindle%" -o "%src_oem%\batch\launch_kindle.bat"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to fetch launch script: launch_kindle.bat
)

curl -sSL "%src_remove_drm%" -o "%src_oem%\batch\remove_drm.bat"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to fetch launch script: remove_drm.bat
)

copy /Y %src_oem%\batch\*.bat "%ProgramFiles(x86)%\Amazon\Kindle" > nul 2>&1
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to copy launch scripts.
)


set "src_desktop_extract_keys=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/desktop/Extract+Keys+(After+Download).lnk;h=4e25fb84241484e6923a3ccc57e08b12eae41901;hb=refs/heads/satsuoni-lcp"
set "src_desktop_kindle_wrapped=%src_dedrm_git%;a=blob;f=Other_Tools/Turnkey_Windows_install/desktop/Kindle+(Wrapped).lnk;h=e3a1ee9f7a5134fdcc983e473420b79fd845bc3d;hb=refs/heads/satsuoni-lcp"



:: Install Desktop Icons...
echo [*] Download and Install Desktop Icons...

mkdir "%src_oem%\desktop" > nul 2>&1
del /Q "%src_oem%\desktop\*" > nul 2>&1

curl -sSL "%src_desktop_disable_ethernet%" -o "%src_oem%\desktop\Disable Ethernet.bat"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to fetch Desktop utility: Disable Ethernet.bat
)

curl -sSL "%src_desktop_enable_ethernet%" -o "%src_oem%\desktop\Enable Ethernet.bat"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to fetch Desktop utility: Enable Ethernet.bat
)

curl -sSL "%src_desktop_extract_keys%" -o "%src_oem%\desktop\Extract Keys (After Download).lnk"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to fetch launch script: Extract Keys After Download.lnk
)

curl -sSL "%src_desktop_kindle_wrapped%" -o "%src_oem%\desktop\Kindle (Wrapped).lnk"
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to fetch launch script: Kindle Wrapped.lnk
)

copy /Y %src_oem%\desktop\* "%public%\Desktop" > nul 2>&1
if errorlevel 1 (
    >>"%log%" echo [%timestamp%] [ERROR] Failed to copy desktop icons.
)

del /Q "%userprofile%\Desktop\Kindle.lnk" > nul 2>&1
del /Q "%public%\Desktop\Kindle.lnk" > nul 2>&1

:: Remove Hosts Override
copy /Q "%src_oem%\hosts.backup" "%SystemRoot%\System32\drivers\etc\hosts" > nul 2>&1
if not errorlevel 1 (
    del /Q "%src_oem%\hosts.backup"
)

endlocal
