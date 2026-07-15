$sh = New-Object -ComObject WScript.Shell
$target = $sh.CreateShortcut('C:\Users\Admin\Desktop\Namba Server.lnk')
Write-Host "TargetPath: $($target.TargetPath)"
Write-Host "Arguments: $($target.Arguments)"
Write-Host "WorkingDirectory: $($target.WorkingDirectory)"
