const fs = require('fs');
const file = 'D:/New folder (2)/namba_admin/lib/super_admin_dashboard.dart';
let content = fs.readFileSync(file, 'utf8');

// 1. Update Full Screen Order Details Bill Summary
const target1 = `                                        _fsPriceRow('Subtotal (Vendor Price)', '₹\${subTotal.toStringAsFixed(2)}'),
                                        if (discount > 0) ...[
                                          const SizedBox(height: 8),
                                          _fsPriceRow('Discount', '-\${discount.toStringAsFixed(2)}', color: Colors.green),
                                        ],`;

const replacement1 = `                                        _fsPriceRow('Subtotal (Vendor Price)', '₹\${subTotal.toStringAsFixed(2)}'),
                                        if (discount > 0) ...[
                                          const SizedBox(height: 8),
                                          _fsPriceRow('Discount', '-\${discount.toStringAsFixed(2)}', color: Colors.green),
                                          const SizedBox(height: 8),
                                          _fsPriceRow('Price (After Discount)', '₹\${((subTotal - discount) > 0 ? (subTotal - discount) : 0.0).toStringAsFixed(2)}', color: const Color(0xFF1E40AF)),
                                        ],`;

// 2. Update Vendor Payout Card Breakdown text
const target2 = `                                          Text(
                                            '(Subtotal ₹' + sub.toStringAsFixed(0) + ' - Platform Commission ₹' + vFee.toStringAsFixed(0) + ')',
                                            style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                          ),`;

const replacement2 = `                                          Builder(builder: (_) {
                                            final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;
                                            final double effectivePrice = (sub - disc) > 0 ? (sub - disc) : sub;
                                            return Text(
                                              disc > 0
                                                ? '(Subtotal ₹' + sub.toStringAsFixed(0) + ' - Discount ₹' + disc.toStringAsFixed(0) + ' = Price ₹' + effectivePrice.toStringAsFixed(0) + ' | Commission ₹' + vFee.toStringAsFixed(0) + ')'
                                                : '(Subtotal ₹' + sub.toStringAsFixed(0) + ' - Platform Commission ₹' + vFee.toStringAsFixed(0) + ')',
                                              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                            );
                                          }),`;

// 3. Update Modal Dialog _showOrderDetails Price rows
const target3 = `                                if (order['discount'] != null && order['discount'] > 0)
                                  _priceRow('Discount', '-₹\${order['discount']}', isBold: false, color: Colors.green),`;

const replacement3 = `                                if (order['discount'] != null && (order['discount'] as num) > 0) ...[
                                  _priceRow('Discount', '-₹\${order['discount']}', isBold: false, color: Colors.green),
                                  Builder(builder: (_) {
                                    final double sub = (order['subTotal'] as num?)?.toDouble() ?? (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
                                    final double disc = (order['discount'] as num?)?.toDouble() ?? 0.0;
                                    final double itemPrice = (sub - disc) > 0 ? (sub - disc) : 0.0;
                                    return _priceRow('Price (After Discount)', '₹\${itemPrice.toStringAsFixed(0)}', isBold: true, color: const Color(0xFF1E40AF));
                                  }),
                                ],`;

const isCRLF = content.includes('\r\n');
const norm = (str) => isCRLF ? str.replace(/\n/g, '\r\n') : str.replace(/\r\n/g, '\n');

let count = 0;
if (content.includes(norm(target1))) { content = content.replace(norm(target1), norm(replacement1)); count++; }
if (content.includes(norm(target2))) { content = content.replace(norm(target2), norm(replacement2)); count++; }
if (content.includes(norm(target3))) { content = content.replace(norm(target3), norm(replacement3)); count++; }

fs.writeFileSync(file, content, 'utf8');
console.log(`Successfully updated ${count} Price / Discount sections in super_admin_dashboard.dart!`);
