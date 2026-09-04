@echo off
title Koka-Kolya - Full Test Suite Runner
echo ========================================================
echo        Запуск полного набора автотестов (12 сьютов)
echo ========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\tools\run_all_tests.ps1"
pause