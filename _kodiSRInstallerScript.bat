@echo off
echo.
echo.
title Kodi Screen Reader Installer Script
cls
:: enable extensions for ensure if and mkdir behavior
setlocal EnableExtensions
:: get/set Kodi
set p1="%ProgramFiles%\Kodi\kodi.exe"
if exist %p1% (
	set kodiExe=%p1%
)
set p2="%ProgramFiles(X86)%\Kodi\kodi.exe"
if exist %p2% (
	set kodiExe=%p2%
)
if not defined kodiExe (
	echo Kodi not found^!
	echo Please install it, in default directory;
	echo then execute this script again.
	pause
	goto :eof
)
echo Ok, Kodi found^!
:: use a working dir
echo Create working dir...
set workingDir="%tmp%\__kodiSRInstallerScript__"
mkdir %workingDir%>nul 2>nul
:: get/set Curl
curl.exe --version>nul 2>nul
if %errorlevel% neq 0 (
	call :getCurl
	set curlExe=%workingDir%\curlDir\bin\curl.exe --silent --retry 3
) else (
	set curlExe=curl.exe --silent --retry 3
)
:: check :getCurl result
if %errorlevel% neq 0 (
	echo Sorry, something went wrong with Curl. Try later.
	goto :badFinish
)
:: download stuff
echo Downloading service.xbmc.tts...
set url1="https://codeload.github.com/pvagner/service.xbmc.TTS/zip/2to3"
%curlExe% --output %workingDir%\service.xbmc.tts.zip %url1%
echo Downloading backends...
set url2="https://codeload.github.com/pvagner/backends/zip/2to3"
%curlExe% --output %workingDir%\backends.zip %url2%
echo Downloading nvda_controllerClient...
set url3="https://www.nvaccess.org/files/nvda/releases/stable/"
%curlExe% --output %workingDir%\nvda-files.htm %url3%
set namePart=
if not exist %workingDir%\nvda-files.htm (
	echo Sorry, something went wrong with NVDA stuff. Try later.
	goto :badFinish
)
for /f "tokens=2 delims==>" %%a in ('findstr "controllerClient.zip" %workingDir%\nvda-files.htm') do (
	set namePart=%%~a
)
%curlExe% --output %workingDir%\nvda_controllerClient.zip %url3%%namePart%
:: extract stuff
echo Building Kodi addon...
:: set and create base dir
set dir1=%workingDir%\Kodi\addons
mkdir %dir1%>nul 2>nul
:: extract and adjust service.xbmc.tts
call :psUnzip service.xbmc.tts.zip %dir1%
ren %dir1%\service.xbmc.tts-2to3 service.xbmc.tts>nul 2>nul
:: clean from .git files
del /q %dir1%\service.xbmc.tts\.*>nul 2>nul
:: extract and adjust backends
set dir2=%dir1%\service.xbmc.tts\Lib
rmdir /s /q %dir2%\backends>nul 2>nul
call :psUnzip backends.zip %dir2%
ren %dir2%\backends-2to3 backends>nul 2>nul
:: extract and adjust nvdaControllerClient
mkdir %workingDir%\nvdaControllerClient>nul 2>nul
call :psUnzip nvda_controllerClient.zip %workingDir%\nvdaControllerClient
set dir3=%dir2%\backends\nvda
mkdir %dir3%>nul 2>nul
move /y %workingDir%\nvdaControllerClient\x86\nvdaControllerClient32.dll %dir3%\>nul 2>nul
move /y %workingDir%\nvdaControllerClient\x64\nvdaControllerClient64.dll %dir3%\>nul 2>nul
:: copy .json to avoid problems with path
copy /y "%~dp0enableAddonCommand.json" %workingDir%\>nul 2>nul
:: verify
echo Verify:
set stop=0
if exist %dir1% (
	echo Folder addons OK
) else (set stop=1 && goto :stopVerify)
if exist %dir1%\service.xbmc.tts\*.py (
	echo Folder service.xbmc.tts OK
) else (set stop=2 && goto :stopVerify)
if exist %dir2%\backends\*.py (
	echo Folder backends OK
) else (set stop=3 && goto :stopVerify)
if exist %dir3%\*.dll (
	echo Folder nvda OK
) else (set stop=4 && goto :stopVerify)
if exist %workingDir%\enableAddonCommand.json (
	echo File json OK
) else (set stop=5)
:stopVerify
if %stop% neq 0 (
	echo Sorry, something went wrong. Try later.
	echo Error code: %stop%
	goto :badFinish
)
:: copy in %appdata%
xcopy /s /i /q /y %workingDir%\Kodi "%appdata%\Kodi">nul 2>nul
if not exist "%appdata%\Kodi\addons\service.xbmc.tts" (
	echo Sorry, something went wrong copying in appdata. Try later.
	goto :badFinish
)
:: start Kodi
echo Launching Kodi...
start "" %kodiExe%
:: wait 5 seconds for Kodi is ready
ping -n 5 localhost>nul 2>nul
echo Enabling addon...
call :enableAddon
goto :finish

:getCurl
powershell -command "echo Ok!">nul 2>nul
if %errorlevel% neq 0 (
 echo Curl not present and impossible to download^!
 echo Sorry, the installation cannot proceed.
 exit /b %errorlevel%
)
echo Downloading Curl...
set url0="https://curl.se/windows/latest.cgi?p=win32-mingw.zip"
powershell -noLogo -noProfile -command "(New-Object System.Net.WebClient).DownloadFile('%url0%', '%workingDir%\curl.zip')"
echo Extracting Curl...
call :psUnzip curl.zip %workingDir%
move /y %workingDir%\curl-* %workingDir%\curlDir>nul 2>nul
exit /b %errorlevel%

:psUnzip
:: %1: filename.zip
:: %2: where extract to
powershell -noLogo -noProfile -command "&{ $shell = New-Object -COM Shell.Application; $target = $shell.NameSpace('%2'); $zip = $shell.NameSpace('%workingDir%\%1'); $target.CopyHere($zip.Items(), 16); }"
goto :eof

:enableAddon
%curlExe% --include --request POST --header "Content-Type:application/json" --data @%workingDir%\enableAddonCommand.json "http://localhost:9090/jsonrpc?request="
goto :eof

:badFinish
rmdir /s /q %workingDir%>nul 2>nul
pause
goto :eof

:finish
rmdir /s /q %workingDir%>nul 2>nul
echo DONE^!
pause
