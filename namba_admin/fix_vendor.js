const fs = require('fs');
const file = 'D:/New folder (2)/namba_admin/lib/super_admin_dashboard.dart';
let content = fs.readFileSync(file, 'utf8');

const target = `                                  // Big status card
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [statusColor.withOpacity(0.08), statusColor.withOpacity(0.02)],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                                          child: Icon(statusIcon, color: statusColor, size: 28),
                                        ),
                                        const SizedBox(width: 16),
                                  // Order time`;

const replacement = `                                  // Big status card
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [statusColor.withOpacity(0.08), statusColor.withOpacity(0.02)],
                                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
                                          child: Icon(statusIcon, color: statusColor, size: 28),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('CURRENT STATUS', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                              const SizedBox(height: 4),
                                              Text(_vendorStatusLabel(status), style: GoogleFonts.outfit(color: statusColor, fontWeight: FontWeight.w900, fontSize: 15)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  _fsInfoRow(Icons.store_rounded, 'Store', vendorName, Colors.blue.shade700),
                                  const SizedBox(height: 12),
                                  _fsInfoRow(Icons.category_rounded, 'Category', order['vendor']?['category'] ?? 'N/A', Colors.purple.shade600),
                                  const SizedBox(height: 12),
                                  _fsInfoRow(Icons.location_on_rounded, 'Address', order['vendor']?['address'] ?? 'N/A', Colors.red.shade600),
                                  const SizedBox(height: 24),
                                  // Order time`;

const isCRLF = content.includes('\r\n');
const normalizedTarget = isCRLF ? target.replace(/\n/g, '\r\n') : target.replace(/\r\n/g, '\n');
const normalizedReplacement = isCRLF ? replacement.replace(/\n/g, '\r\n') : replacement.replace(/\r\n/g, '\n');

if (content.includes(normalizedTarget)) {
  content = content.replace(normalizedTarget, normalizedReplacement);
  fs.writeFileSync(file, content, 'utf8');
  console.log('Successfully restored middle column!');
} else {
  console.log('Target not found!');
}
