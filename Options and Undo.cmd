@echo off
rem  Extract All with 7-Zip - opens the window with the options and the "Undo - back to Windows default" button.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0ExtractAllWith7Zip.ps1"
