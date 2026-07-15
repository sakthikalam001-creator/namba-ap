const { exec } = require('child_process');
const cmd = `powershell -command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut('C:\\Users\\Admin\\Desktop\\Namba Server.lnk'); $s.TargetPath; $s.Arguments; $s.WorkingDirectory"`;
exec(cmd, (err, stdout, stderr) => {
  if (err) {
    console.error(err);
    return;
  }
  console.log(stdout);
});
