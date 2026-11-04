@echo off
rem Blood Reborn - abre o instalador / opens the installer
start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0instalador\BloodReborn.ps1"
