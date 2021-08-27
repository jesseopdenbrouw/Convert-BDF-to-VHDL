@echo off

start install_flow.vbs

exit 0

rem Original script contents follows.
rem
rem  install_flow.cmd
rem
rem       installs the BDF Flow file and Quartus INI file for current user
rem
rem       (c)2013 De Haagse Hogeschool, Jesse op den Brouw
rem

echo Installing BDF Flow...
if not exist h: goto nohdrive

rem Check for files
if not exist tmwc_BDF_Compile_And_Simulation.tmf goto nofiles
if not exist quartus2.ini goto nofiles

if defined userprofile copy tmwc_BDF_Compile_And_Simulation.tmf "%USERPROFILE%"
if defined userprofile copy quartus2.ini "%USERPROFILE%"
goto waitforkey

:nohdrive
echo.
echo ********
echo.
echo Error: There is no H: drive.
echo.
echo Check for existence or use the SUBST command to implement a virtual H: drive
echo.
echo Example:     SUBST H:   D:\some\path
echo.
echo Flow is NOT installed. Bailing out!
echo.
echo ********
echo.
goto waitforkey

:nofiles
echo.
echo ********
echo.
echo Error: Files missing
echo.
echo Important files are not found. Are you running from a compressed file?
echo.
echo Flow is NOT installed. Bailing out!
echo.
echo ********
echo.

:waitforkey
pause
