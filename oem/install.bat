REM @echo off
setlocal enabledelayedexpansion


:: Color stuff
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "cyan=%ESC%[96m"
set "green=%ESC%[92m"
set "yellow=%ESC%[93m"
set "red=%ESC%[91m"
set "reset=%ESC%[0m"


:: This segment specifies where files are coming from.
set "src_oem=%systemdrive%\OEM"
set "log=%src_oem%\install.log"

set "src_openssl=https://download.firedaemon.com/FireDaemon-OpenSSL/FireDaemon-OpenSSL-x64-3.6.0.exe"


:: Create download directory
mkdir "%src_oem%"           >nul 2>&1
mkdir "%src_oem%\downloads" >nul 2>&1
mkdir "%src_oem%\bin"       >nul 2>&1


call :section "Primary Installer (Admin)"

:: Check/Install openssl
call :step "Check for and install OpenSSL"
where openssl > nul 2>&1
if errorlevel 1 (
    call :warn "OpenSSL not found in PATH."
    call :fetch "OpenSSL" "openssl-installer.exe" "%src_openssl%"
    call :power "Start-Process '%src_oem%\downloads\openssl-installer.exe' -ArgumentList '/exenoui /exelog fdopenssl3.log /qn /norestart REBOOT=ReallySuppress APPDIR=%src_oem%\openssl ADJUSTSYSTEMPATHENV=yes' -Wait"
    if errorlevel 1 (
        call :err "OpenSSL failed to install."
    )
)
call :suc "OpenSSL OK"


:: Other Packages
call :step "Extracting other packages..."
"%src_oem%\openssl\bin\openssl" enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\blob" -out "%src_oem%\srcfiles.zip" -pass "file:%src_oem%\secret"
if errorlevel 1 (
    call :err "Error decrypting srcfiles.zip."
)
"%src_oem%\openssl\bin\openssl" enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\blob2" -out "%src_oem%\install2-admin.bat" -pass "file:%src_oem%\secret"
if errorlevel 1 (
    call :err "Error decrypting install2-admin.bat."
)
"%src_oem%\openssl\bin\openssl" enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\blob3" -out "%src_oem%\install2-user.bat" -pass "file:%src_oem%\secret"
if errorlevel 1 (
    call :err "Error decrypting install2-user.bat."
)
call :power "Expand-Archive -Path '%src_oem%\srcfiles.zip' -DestinationPath '%src_oem%' -Force"
if errorlevel 1 (
    call :err "Error unzipping srcfiles.zip"
)
call :suc "Packages OK."


call :step "Cleanup..."
move "%src_oem%\srcfiles\*" "%src_oem%\downloads" > nul 2>&1
rmdir "%src_oem%\srcfiles" > nul 2>&1
REM del /Q "%src_oem%\srcfiles.zip" "%src_oem%\blob*" > nul 2>&1
call :suc "Cleanup OK."


call :step "Launching secondary installer..."
"%src_oem%\install2-admin.bat"

pause

endlocal
exit 0



:: powershell launch
:power
    powershell -NoProfile -ExecutionPolicy Bypass -Command "%~1; if (-not $?) { exit 1 }"
    set "rc=%errorlevel%"
exit /b !rc!


:: Fetch something.
:: call :fetch <title> <filename> <url>
:fetch
  call :step "Downloading: %~1"
  curl -fsSL -o "%src_oem%\downloads\%~2" "%~3"
  if errorlevel 1 (
    call :err "Failed to download: %~1"
  )
  call :suc "Downloaded: %~1"
exit /b %errorlevel%


:: Various printing and logging.
:section
  echo %cyan%******************************************************************%reset%
  echo %cyan%*  %~1%reset%
  echo %cyan%******************************************************************%reset%
exit /b

:step
  echo %cyan%[*] %~1 %reset%
  call :log "%~1"
exit /b

:suc
  echo %green%[*] %~1 %reset%
  call :log "%~1"
exit /b

:warn
  echo %yellow%[!] %~1 %reset%
  call :log "%~1"
exit /b

:err
  echo %red%[!!] %~1 %reset%
  call :log "%~1"
  call :step "Exiting..."
  pause
exit 1

:log
  echo [%date% %time%] %~1 >> "%log%"
exit /b
