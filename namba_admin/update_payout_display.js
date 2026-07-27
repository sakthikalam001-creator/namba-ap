const fs = require('fs');
const file = 'D:/New folder (2)/namba_admin/lib/super_admin_dashboard.dart';
let content = fs.readFileSync(file, 'utf8');

const target = `                                   Builder(builder: (context) {
                                     final isVendorPaid = (order['vendorPaymentStatus']?.toString().toUpperCase() == 'PAID') ||
                                                          (order['vendorPaid'] == true);

                                     final double sub = (order['subTotal'] as num?)?.toDouble() ?? 
                                                        ((items as List).fold(0.0, (sum, it) => sum + (((it['price'] ?? 0) as num).toDouble() * ((it['quantity'] ?? 1) as num).toInt())));
                                     final double vFee = (order['vendorFee'] as num?)?.toDouble() ?? (order['platformFee'] as num?)?.toDouble() ?? 0.0;
                                     final double netPayout = (order['vendorEarnings'] as num?)?.toDouble() ?? (sub > 0 ? (sub - vFee) : 0.0);`;

const replacement = `                                   Builder(builder: (context) {
                                     final isVendorPaid = (order['vendorPaymentStatus']?.toString().toUpperCase() == 'PAID') ||
                                                          (order['vendorPaid'] == true);

                                     final double sub = (order['subTotal'] as num?)?.toDouble() ?? 
                                                        ((items as List).fold(0.0, (sum, it) => sum + (((it['price'] ?? 0) as num).toDouble() * ((it['quantity'] ?? 1) as num).toInt())));
                                     final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;
                                     final double itemPriceAfterDiscount = (sub - disc) > 0 ? (sub - disc) : sub;
                                     final double vFee = (order['vendorFee'] as num?)?.toDouble() ?? (order['platformFee'] as num?)?.toDouble() ?? 0.0;
                                     final double netPayout = itemPriceAfterDiscount;`;

const isCRLF = content.includes('\r\n');
const norm = (str) => isCRLF ? str.replace(/\n/g, '\r\n') : str.replace(/\r\n/g, '\n');

if (content.includes(norm(target))) {
  content = content.replace(norm(target), norm(replacement));
  fs.writeFileSync(file, content, 'utf8');
  console.log('Successfully updated Vendor Payout calculation to Item Price after discount (80)!');
} else {
  console.log('Target not found!');
}
