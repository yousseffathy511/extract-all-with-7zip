@echo off
rem  Extract All with 7-Zip - double-click to set everything up in one go.
rem  Free tool. Downloads 7-Zip from its official source if it is missing.
rem  Windows asks for permission once (needed to change the right-click menu) - click "Yes".
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0ExtractAllWith7Zip.ps1" -Install
