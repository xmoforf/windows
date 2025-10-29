@echo off
setlocal enabledelayedexpansion

:: This segment specifies where files are coming from.
set "src_oem=%programdata%\dedrm"

mkdir "%src_oem%"           >nul 2>&1
mkdir "%src_oem%\var"           >nul 2>&1
mkdir "%src_oem%\var\log"       >nul 2>&1
set "log=%src_oem%\var\log\install.log"

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
call :section "Initialization..."

call :step "Initializing download and installation directories."
mkdir "%src_oem%"           >nul 2>&1
mkdir "%src_oem%\bin"       >nul 2>&1
mkdir "%src_oem%\downloads" >nul 2>&1
mkdir "%src_oem%\etc"       >nul 2>&1
mkdir "%src_oem%\share"     >nul 2>&1
mkdir "%src_oem%\src"       >nul 2>&1

:call step "Checking secret..."
if exist "%systemdrive%\OEM\secret" (
    move "%systemdrive%\OEM\secret" "%src_oem%\etc" > nul 2>&1
)
if not exist "%src_oem%\etc\secret" (
    call :err "Missing secret (%src_oem%\secret)."
)

:: Actions needed if performing an update
if not exist "%src_oem%\etc\default_username" (
    call :step "Recording default username as current user."
    echo %username% > "%src_oem%\etc\default_username"
)



call :section "Primary Installer (Admin)"

:: Check/Install openssl
call :step "Check for and install OpenSSL"
where openssl > nul 2>&1
if errorlevel 1 (
    call :warn "OpenSSL not found in PATH."
    call :fetch "OpenSSL" "openssl-installer.exe" "%src_openssl%"
    pushd "%src_oem%\share"
    call :power "Start-Process '%src_oem%\downloads\openssl-installer.exe' -ArgumentList '/exenoui /exelog %src_oem%\log\fdopenssl3.log /qn /norestart REBOOT=ReallySuppress APPDIR=%src_oem%\share\openssl ADJUSTSYSTEMPATHENV=yes' -Wait"
    popd
    if errorlevel 1 (
        call :err "OpenSSL failed to install."
    )
) else (
    call :warn "OpenSSL already installed. Leaving existing OpenSSL."
)
call :suc "OpenSSL OK"


:: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ::
call :section "Download latest update"

call :step "Fetching blobs..."
if not exist override (
    call :fetch "Blob 1" "blob"   "%src_blobs%/blob"
    if errorlevel 1 (
        call :err "Failed to move encrypted blobs from download directory."
    )
    call :suc "Blobs Download OK"
) else (
    copy override "%src_oem%\downloads\blob"
)

:: %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% ::
call :section "Bootstrap"

call :step "Decrypting blob: srcfiles.zip..."
"%src_oem%\share\openssl\bin\openssl" enc -d -aes-256-cbc -pbkdf2 -in "%src_oem%\downloads\blob" -out "%src_oem%\src\srcfiles.zip" -pass "file:%src_oem%\etc\secret"
if errorlevel 1 (
    call :err "Error decrypting srcfiles.zip."
)

call :step "Extracting srcfiles.zip..."
call :power "Expand-Archive -Path '%src_oem%\src\srcfiles.zip' -DestinationPath '%src_oem%' -Force"
if errorlevel 1 (
    call :err "Error unzipping srcfiles.zip"
)
call :suc "Exctraction OK."

call :step "Detecting Docker..."
    if not exist "%systemdrive%\OEM\docker" (
        type nul > "%src_oem%\etc\installed"
    )
call :step "Launching secondary installer..."
cd "%src_oem%\share\installer"
call :power "Start-Process cmd.exe -ArgumentList '/c %src_oem%\share\installer\install2-admin.bat' -Verb RunAs -Wait"

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
              set "release_tag=!release_tag:"=!"
              goto :_check_release_done
          )
      )
  )
  :_check_release_done
  call :trim release_tag
exit /b


:: trim whitespace from variable name
:trim
    set "_trim_name=%~1"
    for /f "tokens=* delims= " %%a in ("!%_trim_name%!") do set "val=%%a"
    for /l %%a in (1,1,100) do if "!val:~-1!"==" " set "val=!val:~0,-1!"
    set "%_trim_name%=%val%"
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
  echo:
  echo %cyan%******************************************************************%reset%
  echo %cyan%* %~1%reset%
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
  echo %yellow%[W] %~1 %reset%
  call :log "%~1"
exit /b

:err
  echo %red%[E] %~1 %reset%
  call :log "%~1"
  call :step "Exiting..."
  pause
exit 1

:log 
  echo [%date% %time%] %~1 >> "%log%"
exit /b
