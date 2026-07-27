const fs = require('fs');
const file = 'D:/New folder (2)/namba_admin/lib/super_admin_dashboard.dart';
let content = fs.readFileSync(file, 'utf8');
const lines = content.split(/\r?\n/);
console.log('Total lines:', lines.length);

// Find index of 'DateFormat(\'hh:mm a\').format(DateTime.parse(order[\'billUploadedAt\']'
const idx = lines.findIndex(l => l.includes("order['billUploadedAt'].toString()"));
console.log('Found line at index:', idx);

if (idx !== -1) {
  // Replace lines idx+6 to idx+11 (which correspond to lines 4696 to 4701)
  const replacement = [
    "                                         Builder(builder: (context) {",
    "                                           final rawPath = order['billPhotoPath']?.toString() ?? '';",
    "                                           final cleanRaw = rawPath.replaceAll('\\\\', '/');",
    "                                           final billUrl = (cleanRaw.startsWith('http') || cleanRaw.contains(':\\\\'))",
    "                                               ? cleanRaw",
    "                                               : `${_SuperAdminDashboardState._baseUrl.split('/api').first}${cleanRaw.startsWith('/') ? '' : '/'}${cleanRaw}`;",
    "                                           return GestureDetector(",
    "                                             onTap: () => _showImagePreviewDialog(billUrl, 'OFFICIAL RECEIPT'),",
    "                                             child: MouseRegion(",
    "                                               cursor: SystemMouseCursors.zoomIn,",
    "                                               child: ClipRRect(",
    "                                                 borderRadius: BorderRadius.circular(12),",
    "                                                 child: _buildResponsiveImage(rawPath, maxHeight: 350),",
    "                                               ),",
    "                                             ),",
    "                                           );",
    "                                         }),"
  ];
  // Replace 6 lines starting from idx+6
  lines.splice(idx + 6, 6, ...replacement);
  const isCRLF = content.includes('\r\n');
  fs.writeFileSync(file, lines.join(isCRLF ? '\r\n' : '\n'), 'utf8');
  console.log('Successfully updated super_admin_dashboard.dart!');
}
