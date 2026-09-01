import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import '../../models/rider_notification.dart';
import '../../providers/delivery_provider.dart';
import '../../theme/app_theme.dart';
import '../earnings/rider_earnings_screen.dart';
import '../profile/document_status_screen.dart';
import '../support/rider_chatbot_screen.dart';
import '../orders/delivery_order_detail_screen.dart';

class RiderNotificationsScreen extends StatefulWidget {
  const RiderNotificationsScreen({super.key});

  @override
  State<RiderNotificationsScreen> createState() => _RiderNotificationsScreenState();
}

class _RiderNotificationsScreenState extends State<RiderNotificationsScreen> {
  NotificationCategory _selectedCategory = NotificationCategory.all;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeliveryProvider>(context);
    final allNotifications = provider.notifications;
    final filteredNotifications = _selectedCategory == NotificationCategory.all
        ? allNotifications
        : allNotifications.where((n) => n.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context, provider),
      body: Column(
        children: [
          _buildCategoryFilterBar(allNotifications),
          Expanded(
            child: filteredNotifications.isEmpty
                ? _buildEmptyState()
                : _buildNotificationsList(provider, filteredNotifications),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, DeliveryProvider provider) {
    final unreadCount = provider.unreadNotificationsCount;

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.darkText),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'NOTIFICATIONS',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.2,
                  color: AppTheme.darkText,
                ),
              ),
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$unreadCount NEW',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(
            'Fleet Alerts & System Updates',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.lightText,
            ),
          ),
        ],
      ),
      actions: [
        if (provider.notifications.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppTheme.darkText),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              if (val == 'mark_read') {
                HapticFeedback.lightImpact();
                provider.markAllNotificationsAsRead();
              } else if (val == 'clear_all') {
                _showClearConfirmation(context, provider);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'mark_read',
                child: Row(
                  children: [
                    const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 10),
                    Text('Mark all as read', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                    const SizedBox(width: 10),
                    Text('Clear all alerts', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }

  Widget _buildCategoryFilterBar(List<RiderNotification> allNotifications) {
    final categories = [
      {'cat': NotificationCategory.all, 'label': 'All'},
      {'cat': NotificationCategory.order, 'label': 'Orders'},
      {'cat': NotificationCategory.payout, 'label': 'Payouts'},
      {'cat': NotificationCategory.kyc, 'label': 'KYC / Docs'},
      {'cat': NotificationCategory.support, 'label': 'Support'},
      {'cat': NotificationCategory.system, 'label': 'System'},
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: categories.map((item) {
            final cat = item['cat'] as NotificationCategory;
            final isSelected = _selectedCategory == cat;
            final count = cat == NotificationCategory.all
                ? allNotifications.length
                : allNotifications.where((n) => n.category == cat).length;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedCategory = cat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item['label'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(icons.Iconsax.notification_bing_copy, size: 48, color: Color(0xFF94A3B8)),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(
              'No Notifications Yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up! Order alerts, payout credits, and dispatch broadcasts will appear here in real-time.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.lightText,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList(DeliveryProvider provider, List<RiderNotification> list) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const BouncingScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Dismissible(
          key: Key(item.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ),
          onDismissed: (_) {
            provider.removeNotification(item.id);
            HapticFeedback.lightImpact();
          },
          child: _buildNotificationCard(context, provider, item, index),
        );
      },
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    DeliveryProvider provider,
    RiderNotification notif,
    int index,
  ) {
    final catDetails = _getCategoryVisuals(notif.category);

    return GestureDetector(
      onTap: () {
        provider.markNotificationAsRead(notif.id);
        _handleNotificationAction(context, notif);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.isRead ? Colors.white : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: notif.isRead ? const Color(0xFFE2E8F0) : catDetails['color'] as Color,
            width: notif.isRead ? 1 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: notif.isRead
                  ? Colors.black.withValues(alpha: 0.02)
                  : (catDetails['color'] as Color).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Icon Badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (catDetails['color'] as Color).withValues(alpha: 0.15),
                    (catDetails['color'] as Color).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (catDetails['color'] as Color).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(catDetails['icon'] as IconData, color: catDetails['color'] as Color, size: 22),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: GoogleFonts.outfit(
                            fontWeight: notif.isRead ? FontWeight.w800 : FontWeight.w900,
                            fontSize: 14,
                            color: AppTheme.darkText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notif.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: catDetails['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif.body,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475569),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTimestamp(notif.timestamp),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                      if (notif.data != null && notif.data!.isNotEmpty)
                        Text(
                          'TAP TO VIEW →',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: catDetails['color'] as Color,
                            letterSpacing: 0.5,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 40).ms).slideY(begin: 0.05);
  }

  Map<String, dynamic> _getCategoryVisuals(NotificationCategory cat) {
    switch (cat) {
      case NotificationCategory.order:
        return {'color': const Color(0xFF10B981), 'icon': Icons.delivery_dining_rounded};
      case NotificationCategory.payout:
        return {'color': const Color(0xFF6366F1), 'icon': Icons.account_balance_wallet_rounded};
      case NotificationCategory.kyc:
        return {'color': const Color(0xFFF59E0B), 'icon': icons.Iconsax.shield_tick_copy};
      case NotificationCategory.support:
        return {'color': const Color(0xFF8B5CF6), 'icon': Icons.support_agent_rounded};
      case NotificationCategory.system:
      default:
        return {'color': const Color(0xFF3B82F6), 'icon': icons.Iconsax.notification_1_copy};
    }
  }

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  void _handleNotificationAction(BuildContext context, RiderNotification notif) {
    if (notif.category == NotificationCategory.order && notif.data != null && notif.data!['orderId'] != null) {
      final orderId = notif.data!['orderId'].toString();
      Navigator.push(context, MaterialPageRoute(builder: (_) => DeliveryOrderDetailScreen(orderId: orderId)));
    } else if (notif.category == NotificationCategory.payout) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderEarningsScreen()));
    } else if (notif.category == NotificationCategory.kyc) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentStatusScreen()));
    } else if (notif.category == NotificationCategory.support) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderChatbotScreen()));
    }
  }

  void _showClearConfirmation(BuildContext context, DeliveryProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear All Notifications?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Text('This will remove all notification history.', style: GoogleFonts.outfit(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.outfit(color: AppTheme.lightText, fontWeight: FontWeight.w800)),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearAllNotifications();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Clear All', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
