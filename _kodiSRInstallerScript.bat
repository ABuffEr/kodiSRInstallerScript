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
set workingDir="%~dp0__workingDir__"
mkdir %workingDir%>nul 2>nul
:: get/set Curl
curl.exe --version>nul 2>nul
if %errorlevel% neq 0 (
	call :getCurl
	set curlExe=%workingDir%\curlDir\bin\curl.exe --silent
) else (
	set curlExe=curl.exe --silent
)
:: check :getCurl result
if %errorlevel% neq 0 (
	echo Sorry, something went wrong with Curl. Try later.
	pause
	goto :finish
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
	pause
	goto :finish
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
move %workingDir%\nvdaControllerClient\x86\nvdaControllerClient32.dll %dir3%\>nul 2>nul
:: copy in %appdata%
xcopy /s /i /q /y %workingDir%\Kodi "%appdata%\Kodi">nul 2>nul
if not exist "%appdata%\Kodi\addons\service.xbmc.tts" (
	echo Sorry, something went wrong copying in appdata. Try later.
	pause
	goto :finish
)
:: start Kodi
echo Launching Kodi...
start "" /b %kodiExe%
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
powershell -nologo -noprofile -command "(New-Object System.Net.WebClient).DownloadFile('%url0%', '%workingDir%\curl.zip')"
echo Extracting Curl...
call :psUnzip curl.zip %workingDir%
move %workingDir%\curl-* %workingDir%\curlDir>nul 2>nul
exit /b %errorlevel%

:psUnzip
:: %1: filename.zip
:: %2: where extract to
powershell -nologo -noprofile -command "& { $shell = New-Object -COM Shell.Application; $target = $shell.NameSpace('%2'); $zip = $shell.NameSpace('%workingDir%\%1'); $target.CopyHere($zip.Items(), 16); }"
goto :eof

:enableAddon
%curlExe% --include --request POST --header "Content-Type:application/json" --data @enableAddonCommand.json "http://localhost:9090/jsonrpc?request="
goto :eof

:finish
rmdir /s /q %workingDir%>nul 2>nul
echo DONE^!
pause
