@echo off
setlocal
cd /d "%~dp0"
Rscript scripts\run.R %*
exit /b %errorlevel%

