const fs = require('fs');
const file = 'D:/New folder (2)/namba_admin/lib/super_admin_dashboard.dart';
let content = fs.readFileSync(file, 'utf8');

const target = `                                  // Order time
                                  if (order['createdAt'] != null)
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 18, color: AdminColors.primaryIndigo),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('ORDER TIME', style: GoogleFonts.outfit(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                              Text(DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.parse(order['createdAt']).toLocal().toLocal()),
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 13, color: AdminColors.textHeading)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),`;

const insertion = `

                                  const SizedBox(height: 24),
                                  // VENDOR PAYOUT & SETTLEMENT CARD
                                  Builder(builder: (context) {
                                    final isVendorPaid = (order['vendorPaymentStatus']?.toString().toUpperCase() == 'PAID') ||
                                                         (order['vendorPaid'] == true);

                                    final double sub = (order['subTotal'] as num?)?.toDouble() ?? 
                                                       ((items as List).fold(0.0, (sum, it) => sum + (((it['price'] ?? 0) as num).toDouble() * ((it['quantity'] ?? 1) as num).toInt())));
                                    final double vFee = (order['vendorFee'] as num?)?.toDouble() ?? (order['platformFee'] as num?)?.toDouble() ?? 0.0;
                                    final double netPayout = (order['vendorEarnings'] as num?)?.toDouble() ?? (sub > 0 ? (sub - vFee) : 0.0);

                                    return Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: isVendorPaid ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isVendorPaid ? const Color(0xFF86EFAC) : const Color(0xFFBFDBFE),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isVendorPaid ? Colors.green : Colors.blue).withOpacity(0.06),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(children: [
                                                Icon(
                                                  isVendorPaid ? Icons.verified_rounded : Icons.account_balance_wallet_rounded,
                                                  color: isVendorPaid ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'NET VENDOR PAYOUT',
                                                  style: GoogleFonts.outfit(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 12,
                                                    color: isVendorPaid ? const Color(0xFF166534) : const Color(0xFF1D4ED8),
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ]),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isVendorPaid ? const Color(0xFFDCFCE7) : const Color(0xFFDBEAFE),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  isVendorPaid ? 'PAID / DONE' : 'PENDING',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                    color: isVendorPaid ? const Color(0xFF15803D) : const Color(0xFF1E40AF),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            '₹' + netPayout.toStringAsFixed(0),
                                            style: GoogleFonts.outfit(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: isVendorPaid ? const Color(0xFF15803D) : const Color(0xFF1E3A8A),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '(Subtotal ₹' + sub.toStringAsFixed(0) + ' - Platform Commission ₹' + vFee.toStringAsFixed(0) + ')',
                                            style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 16),
                                          if (isVendorPaid)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF15803D),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'VENDOR PAYMENT SETTLED',
                                                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else ...[
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed: onPayVendor,
                                                icon: const Icon(Icons.payments_rounded, size: 18),
                                                label: Text(
                                                  'MARK VENDOR PAID (₹' + netPayout.toStringAsFixed(0) + ')',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF10B981),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  elevation: 2,
                                                ),
                                              ),
                                            ),
                                            if (onOpenPayoutHub != null) ...[
                                              const SizedBox(height: 8),
                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  onPressed: onOpenPayoutHub,
                                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                                  label: Text(
                                                    'GO TO VENDOR PAYOUT HUB',
                                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFF2563EB),
                                                    side: const BorderSide(color: Color(0xFF93C5FD)),
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ],
                                      ),
                                    );
                                  }),`;

const isCRLF = content.includes('\r\n');
const normalizedTarget = isCRLF ? target.replace(/\n/g, '\r\n') : target.replace(/\r\n/g, '\n');
const normalizedInsertion = isCRLF ? insertion.replace(/\n/g, '\r\n') : insertion.replace(/\r\n/g, '\n');

if (content.includes(normalizedTarget)) {
  content = content.replace(normalizedTarget, normalizedTarget + normalizedInsertion);
  fs.writeFileSync(file, content, 'utf8');
  console.log('Successfully inserted Vendor Payout Card!');
} else {
  console.log('Target not found for payout card insertion!');
}
