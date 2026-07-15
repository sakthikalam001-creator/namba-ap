@echo off
setlocal enabledelayedexpansion
title 🚀 NAMBA PLATFORM LAUNCHER
color 0A

echo.
echo  ╔══════════════════════════════════════════════════╗
echo  ║          NAMBA DELIVERY PLATFORM                 ║
echo  ║              AUTO LAUNCHER v1.0                  ║
echo  ╚══════════════════════════════════════════════════╝
echo.

:: ── STEP 1: Check and Start MongoDB ─────────────────────────────────────
echo  [1/2] Checking MongoDB...

:: Check if mongod is already running
tasklist /FI "IMAGENAME eq mongod.exe" 2>NUL | find /I "mongod.exe" >NUL
if %ERRORLEVEL% == 0 (
    echo  ✅ MongoDB is already running!
) else (
    echo  🔄 Starting MongoDB...

    :: Try common MongoDB install locations
    set "MONGOD="
    if exist "C:\Program Files\MongoDB\Server\8.2\bin\mongod.exe" set "MONGOD=C:\Program Files\MongoDB\Server\8.2\bin\mongod.exe"
    if exist "C:\Program Files\MongoDB\Server\8.0\bin\mongod.exe" set "MONGOD=C:\Program Files\MongoDB\Server\8.0\bin\mongod.exe"
    if exist "C:\Program Files\MongoDB\Server\7.0\bin\mongod.exe" set "MONGOD=C:\Program Files\MongoDB\Server\7.0\bin\mongod.exe"
    if exist "C:\Program Files\MongoDB\Server\6.0\bin\mongod.exe" set "MONGOD=C:\Program Files\MongoDB\Server\6.0\bin\mongod.exe"
    if exist "C:\Program Files\MongoDB\Server\5.0\bin\mongod.exe" set "MONGOD=C:\Program Files\MongoDB\Server\5.0\bin\mongod.exe"

    :: Try running mongod from PATH
    where mongod >NUL 2>&1
    if %ERRORLEVEL% == 0 set "MONGOD=mongod"

    if "!MONGOD!"=="" (
        echo  ⚠️  MongoDB not found! Starting MongoDB service instead...
        net start MongoDB >NUL 2>&1
        if %ERRORLEVEL% NEQ 0 (
            echo  ❌ Could not start MongoDB. Please install MongoDB first.
            echo     Download from: https://www.mongodb.com/try/download/community
            timeout /t 5 >NUL
        ) else (
            echo  ✅ MongoDB service started!
        )
    ) else (
        :: Create data directory if it doesn't exist
        if not exist "%~dp0data" mkdir "%~dp0data"

        :: Start MongoDB in a separate minimized window
        start "Namba-MongoDB" /MIN "!MONGOD!" --dbpath "%~dp0data"
        echo  ⏳ Waiting for MongoDB to be ready...
        timeout /t 3 >NUL
        echo  ✅ MongoDB started!
    )
)

echo.

:: ── STEP 2: Start Node.js Backend ────────────────────────────────────────
echo  [2/2] Starting Namba Backend Server...
echo.

cd /d %~dp0

:: Check if node is available
where node >NUL 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo  ❌ Node.js not found! Please install Node.js from https://nodejs.org
    pause
    exit /b 1
)

echo  ╔══════════════════════════════════════════════════╗
echo  ║   🟢 NAMBA BACKEND RUNNING                       ║
echo  ║   📡 API: http://localhost:5000/api/v1            ║
echo  ║   🔌 Socket: ws://localhost:5000                  ║
echo  ║                                                  ║
echo  ║   Press Ctrl+C to stop the server               ║
echo  ╚══════════════════════════════════════════════════╝
echo.

node server.js

echo.
echo  ❌ Server stopped.
pause
