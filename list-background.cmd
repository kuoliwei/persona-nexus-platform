@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0list-background.ps1" %1
