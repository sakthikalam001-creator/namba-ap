import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../models/models.dart';
import 'login_screen.dart';

import 'edit_profile_screen.dart';
import 'saved_addresses_screen.dart';
import 'order_history_screen.dart';

import '../providers/theme_provider.dart';
import 'vendor_dashboard_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final orders = Provider.of<OrderProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
              child: Column(children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 4),
                        image: DecorationImage(
                          image: NetworkImage(auth.profileImage),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded, color: Color(0xFF4F46E5), size: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(auth.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 4),
                Text(auth.email, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _stat('${orders.orders.length}', 'Total Orders'),
                  Container(width: 1, height: 36, color: Colors.white.withOpacity(0.3)),
                  _stat('${orders.orders.where((o) => o.status == OrderStatus.delivered).length}', 'Delivered'),
                ]),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // Wallet Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Namba Wallet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('₹${auth.walletBalance.toStringAsFixed(0)}', 
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Theme.of(context).primaryColor)),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () {
                              auth.addWalletMoney(500); // Corrected method name
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('₹500 added to your wallet!'), backgroundColor: Color(0xFF10B981)),
                              );
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              minimumSize: const Size(0, 30),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('TOP UP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ]),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        const Icon(Icons.stars_rounded, color: Colors.amber, size: 20),
                        const SizedBox(height: 2),
                        Text('${auth.rewardPoints} Pts', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                _buildMenuItem(context, Icons.location_on_rounded, 'Saved Address', auth.address, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedAddressesScreen()));
                }),
                _buildMenuItem(context, Icons.history_rounded, 'Order History', 'View past orders', () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen()));
                }),
                // Dark Mode Toggle
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                      child: Icon(theme.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: Colors.grey, size: 22),
                    ),
                    title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    trailing: Switch(
                      value: theme.isDarkMode,
                      onChanged: (val) => theme.toggleTheme(val),
                      activeColor: const Color(0xFF4F46E5),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),

                _buildMenuItem(context, Icons.help_outline_rounded, 'Help & Support', 'FAQs, Contact us', () {}),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.logout_rounded, color: Colors.red.shade600, size: 22),
                    ),
                    title: Text('Logout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.red.shade600)),
                    subtitle: const Text('Sign out of your account', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
                    onTap: () {
                      auth.logout();
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (_) => false,
                      );
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 120), // Bottom padding for floating nav

              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(children: [
      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
    ]);
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withOpacity(isDark ? 0.15 : 0.08), 
            borderRadius: BorderRadius.circular(10)
          ),
          child: Icon(icon, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
