@echo off
rem #########################################################################
rem ## 
rem ## Release: v0.9 - 03/07/08 
rem ##
rem ## xferDS is a is an automated NintendoDS ROM processing and 
rem ## transfer utility for the R4DS and other flash cartridges. 
rem ##
rem ## Contact: josh.enders@gmail.com
rem ##
rem ## References:
rem ##
rem ## http://www.dostips.com/DtCodeSnippets.php#_Toc141112825
rem ## http://blogs.msdn.com/myocom/archive/2005/06/08/427043.aspx
rem ## http://www.regular-expressions.info/reference.html
rem ## http://technet.microsoft.com/en-us/library/bb491071.aspx
rem ## http://support.microsoft.com/kb/Q71247
rem ## http://www.ss64.com
rem ## http://www.jsifaq.com
rem ## http://www.robvanderwoude.com
rem ##
rem ## Dependencies: 
rem ## 
rem ## http://www.7-zip.org
rem ## http://blog.dev-scene.com/ratx/archives/14
rem ##
rem ## Special thanks to: Pegasus Epsilon and Rob Vanderwoude 
rem ##
rem ## Limitations: Currently does not work with files with !,& or two dashes
rem ## in their filename. 
rem ## 
rem #########################################################################

 setlocal EnableExtensions
 title=[ %~n0 - NDS ROM Transfer Utility ]

 if "%~1"=="" (
   set _INTERACTIVE=yes
   echo No arguments passed. Try '%~n0 --help' for usage.
   echo. 
   echo Beginning interactive mode...
   echo.
   pause 
   goto CONFIGURE
 )

 if /I "%~1"=="--help" goto USAGE
 if /I "%~1"=="--list" ( 
   if not exist "%~2" (
     if not exist "%~dp0%~2" (
       echo "%~2" does not exist! Try '%~n0 --help'
       goto END
     )
   )
   set _LIST=%~2
   goto CONFIGURE
 )
 goto USAGE

:CONFIGURE
 cls & echo.
 set _SETTINGS=%~dp0settings.ini
 set _WORKAREA=%tmp%\xferDS
 if exist "%_WORKAREA%" rd /s /q "%_WORKAREA%" 1>NUL 2>&1
 mkdir "%_WORKAREA%" 1>NUL 2>&1
 mkdir "%_WORKAREA%\ROMS" 1>NUL 2>&1
 if not defined _LIST set _LIST=%_WORKAREA%\xferDS.dat
 if not exist "%_SETTINGS%" (
   if defined _INTERACTIVE (
     echo Cannot find configuration file! Try '%~n0 --help'
     pause
     goto END
   ) else (
     echo Cannot find configuration file! Try '%~n0 --help'
     goto END
   )
 )

 echo Reading settings from configuration file... & echo.
 for /f "usebackq delims== tokens=1*" %%a in (`findstr /v "#" "%_SETTINGS%" ^| findstr "="`) do (
   set _%%a=%%b
   echo %%a=%%b
 )
 set path=%path%;%~dp0%dep\;
 if /I "%~1"=="--list" goto PARSE

:INPUT_LOOP
 echo.
 if exist "%_LIST%" (
   echo.
   type "%_LIST%"
   echo.
 )
 echo Please enter the ROM number followed by the ^<enter^> key. Duplicates and other
 echo erroneous input will be automatically truncated and or discarded.
 echo.
 set /p _input=When you are finished, enter 'q': 

rem ## Eventually this whole routine will be drag and drop based
rem ## This number thing was a bad idea!

 if /I "%_INPUT%"=="q" (
   if not exist "%_LIST%" (
     if defined _INTERACTIVE (
       echo Nothing left to do; exiting.
       echo.
       pause
       goto END
     ) else ( 
       echo.
       echo Nothing left to do; exiting.
       goto END
     )
   )
   goto PARSE
 ) else (
   echo %_INPUT:~0,4%>>"%_LIST%"
   goto INPUT_LOOP
 )

:PARSE
 echo.
 if "%_LIST%"=="%_WORKAREA%\xferDS.dat" ( 
   echo Filtering input... 
 ) else (
   echo Processing "%_LIST%"...
 )
 echo.

 rem ## Remove non-numerical input
 findstr /r "^[0-9][0-9][0-9][0-9]" "%_LIST%" >"%_WORKAREA%\xferDS.lst"

 rem ## Remove duplicates
 call :UNIQ "%_WORKAREA%\xferDS.lst" > "%_WORKAREA%\xferDS.tmp"
 del /f /q "%_WORKAREA%\xferDS.lst" 1>NUL 2>&1

 rem ## Find matches in source directory
 for /f "usebackq" %%a in ("%_WORKAREA%\xferDS.tmp") do (
   if exist "%_SOURCE_PATH%\%%a*" (
     dir /b "%_SOURCE_PATH%\%%a*">>"%_WORKAREA%\xferDS.lst"
   ) else (
     echo Cannot find %%a - Skipping!
   )
 )
 set _LIST=%_WORKAREA%\xferDS.lst

 goto PROCESS

:PROCESS
 setlocal EnableDelayedExpansion
 for /f "usebackq tokens=*" %%a in ("%_LIST%") do (
  
   rem ## Extract and set variable to the name of the extracted rom
   title=[ %~n0 - NDS ROM Transfer Utility ] Extracting - "%%a"
   7z e "%_SOURCE_PATH%\%%a" *.nds -o"%_WORKAREA%\ROMS" -y 1>NUL 2>&1
   for /f "usebackq tokens=*" %%i in (`dir /b "%_WORKAREA%\ROMS\"`) do set _ORIGINALNAME=%%i 
   if exist "%_WORKAREA%\ROMS\!_ORIGINALNAME!" echo Extracted   : "%%a"

   rem ## Run trim.exe which outputs rom.trim.nds.
   if /I "%_TRIM%"=="yes" (
     trim "%_WORKAREA%\ROMS\!_ORIGINALNAME!" 1>NUL 2>&1
     if exist "%_WORKAREA%\ROMS\*.trim.*" echo Trimmed     : !_ORIGINALNAME!

     rem ## Remove the original first and then rename it minus the .trim
     if exist "%_WORKAREA%\ROMS\*.trim.*" (
       del /q /f "%_WORKAREA%\ROMS\!_ORIGINALNAME!" 1>NUL 2>&1
       ren "%_WORKAREA%\ROMS\*.trim.*" "!_ORIGINALNAME!" 1>NUL 2>&1
     )
   )

   rem ## We'll use the - as a delimiter and remove the numerical prefix
   if /I "%_RENAME%"=="yes" (
     rem ## strip archive extension and set _NEWNAME to archive_filename.nds
     for /f "delims=. tokens=1*" %%i in ("%%a") do set _NEWNAME=%%i.nds

     rem ## Lets also remove the numerical prefix and store it in _NEWNAME     
     for /f "tokens=1* delims=- " %%i in ("!_NEWNAME!") do (
      set _NEWNAME=%%j
      ren "%_WORKAREA%\ROMS\!_ORIGINALNAME!" "!_NEWNAME!" 1>NUL 2>&1   
     )
     if exist "%_WORKAREA%\ROMS\!_NEWNAME!" echo Renamed     : !_NEWNAME!
   )

   if defined _RENAME (
     title=[ %~n0 - NDS ROM Transfer Utility ] Transferring - !_NEWNAME!
     move /y "%_WORKAREA%\ROMS\!_NEWNAME!" "%_DESTINATION_PATH%" 1>NUL 2>&1
     if exist "%_DESTINATION_PATH%\!_NEWNAME!" echo Transferred : !_NEWNAME!
     if exist "%_WORKAREA%\ROMS\!_NEWNAME!" echo !_NEWNAME! Failed to transfer!!!
   ) else (
     title=[ %~n0 - NDS ROM Transfer Utility ] Transferring - !_ORIGINALNAME!   
     move /y "%_WORKAREA%\ROMS\!_ORIGINALNAME!" "%_DESTINATION_PATH%" 1>NUL 2>&1
     if exist "%_DESTINATION_PATH%\!_ORIGINALNAME!" echo Transferred : !_ORIGINALNAME!
     if exist "%_WORKAREA%\ROMS\!_ORIGINALNAME!" echo !_ORIGINALNAME! Failed to transfer!!!
   )
   if exist "%_WORKAREA%\ROMS\*.nds"  del /q /f "%_WORKAREA%\ROMS\*.nds" 1>NUL 2>&1
   title=[ %~n0 - NDS ROM Transfer Utility ]
   echo.
 )

 echo Nothing left to do; exiting.
 if defined _INTERACTIVE (
   echo.
   pause
 )
 goto END

:UNIQ
@echo off
rem ## if echo is on here, UNIQ will be redirected to _LIST. We don't want that.

 for /f "usebackq" %%a in (`sort %1`) do call :COMPARE "%%a"
 goto :EOF

:COMPARE
 set _ThisLine=%~1
 if defined _LastLine (
   if not "%_LastLine%"=="%_ThisLine%" (
     set _LastLine=%_ThisLine%
     echo %_ThisLine%
   )
 ) else (
     echo %_ThisLine%
     set _LastLine=%_ThisLine%
 )
 goto :EOF

:USAGE
 echo.
 echo %~n0 is an automated NintendoDS ROM processing and transfer utility for the 
 echo R4DS and other flash cartridges. It can either be run interactively or passed
 echo arguments on the command line.
 echo.
 echo %~n0 [argument]
 echo.
 echo  --help		Display help
 echo  --list="FILE"	Process FILE as a return delimited list of numbered NDS ROMs
 echo.
 echo xferDS expects the presence of a configuration file called 'settings.ini' in
 echo it's immediate path. See documentation for detailed configuration help.
 goto END

:END
 if exist "%_WORKAREA%" rd /s /q "%_WORKAREA%" 1>NUL 2>&1
 title=%comspec%
 endlocal
