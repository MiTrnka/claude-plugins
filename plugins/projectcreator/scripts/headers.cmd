@echo off
rem headersHelper MCP serveru ProjectCreator pro Windows (cmd ho najde přes PATHEXT ze „scripts/headers").
rem Vypíše JSON s hlavičkou Authorization z lokálního souboru s tokenem; token nikam jinam nevypisuje.
setlocal
if defined PROJECTCREATOR_HOME (set "F=%PROJECTCREATOR_HOME%\token") else (set "F=%USERPROFILE%\.claude\projectcreator\token")
set "T="
if exist "%F%" set /p T=<"%F%"
if not defined T goto :missing
echo(%T%| findstr /r /x "pca_[A-Za-z0-9_]*" >nul || goto :missing
echo {"Authorization":"Bearer %T%"}
exit /b 0
:missing
echo ProjectCreator: chybi platny token v "%F%" - spust /projectcreator:setup. 1>&2
exit /b 1
