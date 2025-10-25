REM @echo off
setlocal enabledelayedexpansion

:: This segment specifies where files are coming from.
set "src_oem=%systemdrive%\OEM"
set "log=%src_oem%\install.log"

:: Source URLs
call :check_release
set "src_openssl=https://download.firedaemon.com/FireDaemon-OpenSSL/FireDaemon-OpenSSL-x64-3.6.0.exe"
set "src_blobs=https://raw.githubusercontent.com/xmoforf/windows/refs/tags/%release_tag%/oem/"

:: Color stuff
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "cyan=%ESC%[96m"
set "green=%ESC%[92m"
set "yellow=%ESC%[93m"
set "red=%ESC%[91m"
set "reset=%ESC%[0m"

:: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ::



call: section "Initialization..."

:: Create download directory
call :step "Initializing download and installation directories."
mkdir "%src_oem%"           >nul 2>&1
mkdir "%src_oem%\downloads" >nul 2>&1
mkdir "%src_oem%\bin"       >nul 2>&1

:: Actions needed if performing an update
call :step "Recording default username as current user."
echo %username% > "%src_oem%\default_username"


call :step "Removing any previous instances of install.bat"
del /Q "%userprofile%\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\install.bat"



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
) else (
    call :warn "OpenSSL already installed. Leaving existing OpenSSL."
)
call :suc "OpenSSL OK"



call :section "Download latest update"

:: Grab latest blobs
call :step "Fetching blobs..."
call :fetch "Blob 1" "%src_oem%\blob"   "%src_blobs%/blob"
call :fetch "Blob 2" "%src_oem%\blob2"  "%src_blobs%/blob2"
call :fetch "Blob 3" "%src_oem%\blob3"  "%src_blobs%/blob3"
call :suc "Blobs Download OK"

call :step "Decrypting blob -> srcfiles.zip..."
"%src_oem%\openssl\bin\openssl" enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\blob" -out "%src_oem%\srcfiles.zip" -pass "file:%src_oem%\secret"
if errorlevel 1 (
    call :err "Error decrypting srcfiles.zip."
)

call :step "Decrypting blob2 -> install2-admin.bat..."
"%src_oem%\openssl\bin\openssl" enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\blob2" -out "%src_oem%\install2-admin.bat" -pass "file:%src_oem%\secret"
if errorlevel 1 (
    call :err "Error decrypting install2-admin.bat."
)

call :step "Decrypting blob3 -> install2-user.bat..."
"%src_oem%\openssl\bin\openssl" enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\blob3" -out "%src_oem%\install2-user.bat" -pass "file:%src_oem%\secret"
if errorlevel 1 (
    call :err "Error decrypting install2-user.bat."
)
call :suc "Decryption OK"

call :step "Extracting srcfiles.zip..."
call :power "Expand-Archive -Path '%src_oem%\srcfiles.zip' -DestinationPath '%src_oem%' -Force"
if errorlevel 1 (
    call :err "Error unzipping srcfiles.zip"
)
call :suc "Exctraction OK."

call :step "Cleaning up from extraction..."
move "%src_oem%\srcfiles\*" "%src_oem%\downloads" > nul 2>&1
rmdir "%src_oem%\srcfiles" > nul 2>&1
call :suc "Cleanup OK."

call :step "Launching secondary installer..."
"%src_oem%\install2-admin.bat"

endlocal
goto :eof



:: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ::
:: Functions 
:: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ::



:: Check latest release id
:check_release
  for /f "delims=" %%A in ('curl -s https://api.github.com/repos/xmoforf/windows/releases/latest ^| findstr "\"tag_name\""') do (
      set "LINE=%%A"
      echo !LINE! | findstr "\"tag_name\"" >nul
      if not errorlevel 1 (
          for /f "tokens=2 delims=:" %%B in ("!LINE!") do (
              set "release_tag=%%~B"
              set "release_tag=!release_tag:,=!"
              goto :_check_release_done
          )
      )
  )
  :_check_release_done
exit /b


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
