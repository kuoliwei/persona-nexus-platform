@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0list-fewshots.ps1" %1
