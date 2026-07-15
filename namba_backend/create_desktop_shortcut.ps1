# Namba Platform Desktop Shortcut Creator
$WshShell = New-Object -comObject WScript.Shell
$Desktop = [System.Environment]::GetFolderPath('Desktop')
$Shortcut = $WshShell.CreateShortcut("$Desktop\Namba Server.lnk")

$Shortcut.TargetPath = "C:\Windows\System32\cmd.exe"
$Shortcut.Arguments = "/c `"$PSScriptRoot\namba_launcher.bat`""
$Shortcut.WorkingDirectory = "$PSScriptRoot"
$Shortcut.WindowStyle = 1
$Shortcut.Description = "Start Namba Backend Server + MongoDB"

$NodeCmd = Get-Command node -ErrorAction SilentlyContinue
if ($NodeCmd) {
    $Shortcut.IconLocation = $NodeCmd.Source + ", 0"
} else {
    $Shortcut.IconLocation = "C:\Windows\System32\cmd.exe, 0"
}

$Shortcut.Save()

Write-Host ""
Write-Host "  SUCCESS: Desktop shortcut created!" -ForegroundColor Green
Write-Host "  'Namba Server' shortcut is now on your Desktop." -ForegroundColor Cyan
Write-Host "  Double-click it to auto-start MongoDB + Backend!" -ForegroundColor Yellow
Write-Host ""
