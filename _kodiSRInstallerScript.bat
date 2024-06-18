@echo off
title Kodi Screen Reader Installer Script
:: Author: Alberto Buffolino
:: Version: 1.6 (2024/06/19)
:: License: GPL V2
echo.
:: enable extensions for ensure if and mkdir behavior
setlocal EnableExtensions
:: get/set Kodi
echo Checking Kodi presence...
set portableSetup=0
set p0="%~dp0kodi.exe"
if exist %p0% (
	if exist "%~dp0portable_data" (
		set kodiExe=%p0% -p
		set portableSetup=1
		echo Found portable %p0%
		goto :stopKodiSearch
	)
)
set p1="%ProgramFiles%\Kodi\kodi.exe"
if exist %p1% (
	set kodiExe=%p1%
	echo Found %p1%
	goto :stopKodiSearch
)
set p2="%ProgramFiles(X86)%\Kodi\kodi.exe"
if exist %p2% (
	set kodiExe=%p2%
	echo Found %p2%
	goto :stopKodiSearch
)
if not defined kodiExe (
	echo Kodi not found^!
	echo Please install it, or, if you use Kodi as portable,
	echo put this .bat and .json file where portable_data is located,
	echo then execute this script again.
	pause
	goto :eof
)
:stopKodiSearch
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
	echo Sorry, something went wrong getting Curl.
	echo Check connection or firewall, and retry.
	goto :badFinish
)
:: verify connection
echo Checking connection...
%curlExe% google.com>nul 2>nul
if %errorlevel% neq 0 (
	echo Sorry, unable to download^!
	echo Check connection or firewall, and retry.
	goto :badFinish
)
echo Connection ok^!
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
set dir1=%workingDir%\data\addons
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
move /y %workingDir%\nvdaControllerClient\x86\nvdaControllerClient.dll %dir3%\nvdaControllerClient32.dll>nul 2>nul
move /y %workingDir%\nvdaControllerClient\x64\nvdaControllerClient.dll %dir3%\nvdaControllerClient64.dll>nul 2>nul
move /y %workingDir%\nvdaControllerClient\license.txt %dir3%\>nul 2>nul
:: copy .json to avoid problems with path
copy /y "%~dp0enableAddonCommand.json" %workingDir%\>nul 2>nul
:: verify
echo Verify:
set stop=0
if exist %dir1% (
	echo Folder addons ok.
) else (set stop=1 && goto :stopVerify)
if exist %dir1%\service.xbmc.tts\*.py (
	echo Folder service.xbmc.tts ok.
) else (set stop=2 && goto :stopVerify)
if exist %dir2%\backends\*.py (
	echo Folder backends ok.
) else (set stop=3 && goto :stopVerify)
if exist %dir3%\*.dll (
	echo Folder nvda ok.
) else (set stop=4 && goto :stopVerify)
if exist %workingDir%\enableAddonCommand.json (
	echo File json ok.
) else (set stop=5)
:stopVerify
if %stop% neq 0 (
	echo Sorry, something went wrong. Try later.
	echo Error code: %stop%
	goto :badFinish
)
:: copy in %appdata% or portable_data
if %portableSetup% neq 0 (
	set kodiData="%~dp0portable_data"
) else (
	set kodiData="%appdata%\Kodi"
)
xcopy /s /i /q /y %workingDir%\data %kodiData%>nul 2>nul
if not exist %kodiData%\addons\service.xbmc.tts (
	echo Sorry, something went wrong copying in %kodiData%. Try later.
	goto :badFinish
)
:: start Kodi
echo Launching Kodi...
start "" %kodiExe%
:: wait 10 seconds for Kodi is ready
ping -n 10 localhost>nul 2>nul
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
