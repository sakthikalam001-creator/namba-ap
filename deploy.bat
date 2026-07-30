@echo off
echo ===================================================
echo 🚀 NAMBA AP - 1-CLICK GITHUB PUSH & AWS DEPLOYMENT
echo ===================================================

set COMMIT_MSG=%*
if "%COMMIT_MSG%"=="" set COMMIT_MSG=Auto update

echo.
echo 📦 [1/4] Staging and Committing local changes...
git add .
git commit -m "%COMMIT_MSG%"

echo.
echo 📤 [2/4] Pushing changes to GitHub (origin main)...
git push origin main

echo.
echo ☁️ [3/4] Pulling latest code on AWS EC2 & Restarting Backend...
ssh -i namba-key.pem -o StrictHostKeyChecking=no ubuntu@54.204.9.126 "cd /home/ubuntu/namba-ap && git fetch origin && git reset --hard origin/main && cd /home/ubuntu/namba-ap/namba_backend && pm2 restart server"

echo.
echo 📱 [4/4] Building Vendor Release APK...
cd namba_vendor
call flutter build apk

echo.
echo ===================================================
echo ✅ DEPLOYMENT COMPLETE!
echo ☁️ AWS Backend is Live and Running on PM2!
echo 📱 New APK: D:\New folder (2)\namba_vendor\build\app\outputs\flutter-apk\app-release.apk
echo ===================================================
pause
