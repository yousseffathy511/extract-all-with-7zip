@echo off
rem  Extract All with 7-Zip - double-click to open the setup window.
rem  Free tool. Downloads 7-Zip from its official source if it is missing.
rem  It asks for administrator permission once (needed to change the right-click menu).
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0ExtractAllWith7Zip.ps1"
