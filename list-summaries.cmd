@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0list-summaries.ps1" %1
