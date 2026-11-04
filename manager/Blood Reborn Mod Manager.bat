@echo off
rem Blood Reborn Mod Manager - abre o gerenciador / opens the manager
start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0manager\BloodReborn.ps1"
