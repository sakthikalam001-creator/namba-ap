const fs = require('fs');
const file = 'D:/New folder (2)/namba_admin/lib/super_admin_dashboard.dart';
let content = fs.readFileSync(file, 'utf8');

const targetLine = "final double netPayout = (order['vendorEarnings'] as num?)?.toDouble() ?? (sub > 0 ? (sub - vFee) : 0.0);";
const replacementLine = "final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;\n                                     final double netPayout = (sub - disc > 0) ? (sub - disc) : ((order['vendorEarnings'] as num?)?.toDouble() ?? 0.0);";

const isCRLF = content.includes('\r\n');
const normTarget = targetLine;
const normRepl = isCRLF ? replacementLine.replace(/\n/g, '\r\n') : replacementLine;

if (content.includes(normTarget)) {
  content = content.replace(normTarget, normRepl);
  fs.writeFileSync(file, content, 'utf8');
  console.log('Successfully updated line 10919 to show Price after discount (80)!');
} else {
  console.log('Target line not found directly, splitting by lines...');
  const lines = content.split(/\r?\n/);
  const idx = lines.findIndex(l => l.includes("final double netPayout = (order['vendorEarnings']"));
  console.log('Found line at idx:', idx);
  if (idx !== -1) {
    lines.splice(idx, 1, 
      "                                     final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;",
      "                                     final double netPayout = (sub - disc > 0) ? (sub - disc) : ((order['vendorEarnings'] as num?)?.toDouble() ?? 0.0);"
    );
    fs.writeFileSync(file, lines.join(isCRLF ? '\r\n' : '\n'), 'utf8');
    console.log('Successfully replaced line via index!');
  }
}
