@echo off
title Namba Backend Server
echo.
echo  ================================
echo    Namba Backend Starting...
echo  ================================
echo.
cd /d %~dp0
node server.js
pause
