$WshShell = New-Object -ComObject WScript.Shell
$DesktopPath = [System.Environment]::GetFolderPath('Desktop')
$ShortcutPath = Join-Path -Path $DesktopPath -ChildPath "Deploy Namba App.lnk"
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "D:\New folder (2)\deploy.bat"
$Shortcut.WorkingDirectory = "D:\New folder (2)"
$Shortcut.Description = "1-Click GitHub Push & AWS Deployment for Namba App"
$Shortcut.Save()
Write-Host "✅ Shortcut successfully created at: $ShortcutPath"
