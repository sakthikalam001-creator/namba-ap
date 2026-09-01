import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/delivery_auth_service.dart';
import '../../theme/app_theme.dart';
import '../earnings/rider_earnings_screen.dart';
import 'help_center_screen.dart';
import 'safety_center_screen.dart';

enum ChatSender { user, bot, admin }

class ChatMessage {
  final String id;
  final ChatSender sender;
  final String text;
  final DateTime timestamp;
  final List<ChatAction>? actions;
  final String? ticketId;
  final String? ticketNumber;
  final String? cardType;
  final Map<String, dynamic>? cardData;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.actions,
    this.ticketId,
    this.ticketNumber,
    this.cardType,
    this.cardData,
  });
}

class ChatAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool isPrimary;

  ChatAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.isPrimary = false,
  });
}

class RiderChatbotScreen extends StatefulWidget {
  final String? initialQuery;
  final String? relatedOrderId;
  final String? activeTicketId;

  const RiderChatbotScreen({
    super.key,
    this.initialQuery,
    this.relatedOrderId,
    this.activeTicketId,
  });

  @override
  State<RiderChatbotScreen> createState() => _RiderChatbotScreenState();
}

class _RiderChatbotScreenState extends State<RiderChatbotScreen> with SingleTickerProviderStateMixin {
  int _activeTab = 0; // 0: AI Assistant, 1: Live Admin Chat
  final List<ChatMessage> _aiMessages = [];
  final List<ChatMessage> _liveMessages = [];
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _isTyping = false;
  bool _isVoiceRecording = false;
  bool _isSendingReply = false;
  String _driverName = 'Partner';
  String _driverPhone = '';
  String _driverId = '';

  // Active Ticket tracking
  Map<String, dynamic>? _activeTicket;
  Timer? _liveChatPollTimer;
  bool _isLoadingLiveChat = false;

  final List<Map<String, dynamic>> _quickSuggestions = [
    {
      'label': '💰 Salary / Payout Varala',
      'query': 'salary varala, payout eppo varum?',
      'icon': Icons.account_balance_wallet_rounded,
      'category': 'Payout & Weekly Settlement',
    },
    {
      'label': '📞 Customer Call Edukala',
      'query': 'Customer not reachable / phone switch off',
      'icon': Icons.phone_disabled_rounded,
      'category': 'Customer Not Reachable',
    },
    {
      'label': '🛵 Vandi Breakdown / SOS',
      'query': 'Bike breakdown / Emergency roadside assistance',
      'icon': Icons.two_wheeler_rounded,
      'category': 'Accident / SOS Emergency',
    },
    {
      'label': '📍 Shop Moodiruku / Wrong Map',
      'query': 'Store closed or wrong shop location',
      'icon': Icons.wrong_location_rounded,
      'category': 'Store Closed / Wrong Location',
    },
    {
      'label': '🎁 Today Incentive & Bonus',
      'query': 'Today incentive details and bonus criteria',
      'icon': Icons.workspace_premium_rounded,
      'category': 'General Support',
    },
    {
      'label': '💬 Connect Live Admin Desk',
      'query': 'Connect me to Live Support Executive',
      'icon': Icons.support_agent_rounded,
      'category': 'Live Support',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initRiderData();
    _startLiveChatSync();
  }

  @override
  void dispose() {
    _liveChatPollTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _startLiveChatSync() {
    // Poll every 3.5 seconds to sync Admin replies in real time
    _liveChatPollTimer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (_activeTicket != null && mounted) {
        _syncActiveTicketReplies(silent: true);
      }
    });
  }

  Future<void> _initRiderData() async {
    final name = await DeliveryAuthService.getDriverName();
    final phone = await DeliveryAuthService.getDriverPhone();
    final id = await DeliveryAuthService.getDriverId();

    if (mounted) {
      setState(() {
        if (name.isNotEmpty) _driverName = name;
        _driverPhone = phone;
        _driverId = id;
      });

      _sendInitialGreeting();
      await _loadLatestActiveTicket();

      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _handleUserMessage(widget.initialQuery!);
        });
      }
    }
  }

  Future<void> _loadLatestActiveTicket() async {
    if (_driverPhone.isEmpty) return;
    try {
      final tickets = await DeliveryAuthService.fetchMyTickets(_driverPhone);
      if (tickets.isNotEmpty) {
        // Look for open or in-progress tickets
        final openTicket = tickets.firstWhere(
          (t) => t['status'] == 'Open' || t['status'] == 'In Progress',
          orElse: () => tickets.first,
        );

        if (mounted) {
          setState(() {
            _activeTicket = openTicket;
          });
          _populateLiveChatFromTicket(openTicket);
        }
      }
    } catch (e) {
      debugPrint('Load ticket error: $e');
    }
  }

  void _populateLiveChatFromTicket(Map<String, dynamic> ticket) {
    final replies = (ticket['replies'] as List?) ?? [];
    final List<ChatMessage> msgs = [];
    final ticketId = ticket['_id']?.toString() ?? 'TK';
    final ticketNum = ticket['ticketNumber']?.toString() ?? 'TK';
    final initMsg = (ticket['message'] ?? '').toString().trim();

    if (replies.isNotEmpty) {
      // Check if replies[0] already contains the initial message
      bool initialAlreadyInReplies = false;
      if (initMsg.isNotEmpty) {
        final firstReplyMsg = (replies.first['message'] ?? '').toString().trim();
        if (firstReplyMsg.toLowerCase() == initMsg.toLowerCase()) {
          initialAlreadyInReplies = true;
        }
      }

      // If initial message was not recorded in replies list, prepend it once
      if (initMsg.isNotEmpty && !initialAlreadyInReplies) {
        msgs.add(
          ChatMessage(
            id: '${ticketId}_init',
            sender: ChatSender.user,
            text: initMsg,
            timestamp: DateTime.tryParse(ticket['createdAt'] ?? '') ?? DateTime.now(),
            ticketNumber: ticketNum,
          ),
        );
      }

      for (int i = 0; i < replies.length; i++) {
        final r = replies[i];
        final role = (r['senderRole'] ?? '').toString();
        final isRider = role == 'DeliveryPartner' || role == 'Customer';
        final text = (r['message'] ?? '').toString().trim();
        final timeStr = r['createdAt'] ?? '';
        final time = DateTime.tryParse(timeStr) ?? DateTime.now();

        if (text.isNotEmpty) {
          msgs.add(
            ChatMessage(
              id: '${ticketId}_reply_$i',
              sender: isRider ? ChatSender.user : ChatSender.admin,
              text: text,
              timestamp: time,
              ticketNumber: ticketNum,
            ),
          );
        }
      }
    } else if (initMsg.isNotEmpty) {
      msgs.add(
        ChatMessage(
          id: '${ticketId}_init',
          sender: ChatSender.user,
          text: initMsg,
          timestamp: DateTime.tryParse(ticket['createdAt'] ?? '') ?? DateTime.now(),
          ticketNumber: ticketNum,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _liveMessages.clear();
        _liveMessages.addAll(msgs);
      });
      _scrollToBottom();
    }
  }

  Future<void> _syncActiveTicketReplies({bool silent = false}) async {
    if (_activeTicket == null || _activeTicket!['_id'] == null) return;
    final ticketId = _activeTicket!['_id'];

    if (!silent && mounted) setState(() => _isLoadingLiveChat = true);

    final updated = await DeliveryAuthService.fetchTicketById(ticketId);
    if (updated != null && mounted) {
      setState(() {
        _activeTicket = updated;
        _isLoadingLiveChat = false;
      });
      _populateLiveChatFromTicket(updated);
    } else {
      if (mounted && !silent) setState(() => _isLoadingLiveChat = false);
    }
  }

  void _sendInitialGreeting() {
    final hour = DateTime.now().hour;
    String greetingTime = 'Good Day';
    if (hour < 12) {
      greetingTime = 'Good Morning';
    } else if (hour < 17) {
      greetingTime = 'Good Afternoon';
    } else {
      greetingTime = 'Good Evening';
    }

    _addBotMessage(
      '👋 $greetingTime **$_driverName**!\n\nI am your **Namba 24/7 AI Fleet Support Assistant** (நம்பா உடனடி உதவி பாட்).\n\nEnna help venum? You can ask any question in **Tamil**, **Tanglish**, or **English** regarding Payouts, Orders, SOS, Breakdown, or connect directly to our **Live Admin Desk**.',
      actions: [
        ChatAction(
          label: '💰 Salary / Payout',
          icon: Icons.account_balance_wallet_rounded,
          onTap: () => _handleUserMessage('salary varala, payout eppo varum?'),
        ),
        ChatAction(
          label: '📞 Order Assistance',
          icon: Icons.delivery_dining_rounded,
          onTap: () => _handleUserMessage('Customer not reachable on live order'),
        ),
        ChatAction(
          label: '💬 Live Admin Chat',
          icon: Icons.support_agent_rounded,
          isPrimary: true,
          onTap: () => _switchToLiveChat(autoCreate: true),
        ),
      ],
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addUserMessage(String text, {bool isLiveChat = false}) {
    final newMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sender: ChatSender.user,
      text: text,
      timestamp: DateTime.now(),
    );

    setState(() {
      if (isLiveChat) {
        _liveMessages.add(newMsg);
      } else {
        _aiMessages.add(newMsg);
      }
    });
    _scrollToBottom();
  }

  void _addBotMessage(
    String text, {
    List<ChatAction>? actions,
    String? cardType,
    Map<String, dynamic>? cardData,
  }) {
    setState(() {
      _aiMessages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: ChatSender.bot,
          text: text,
          timestamp: DateTime.now(),
          actions: actions,
          cardType: cardType,
          cardData: cardData,
        ),
      );
    });
    _scrollToBottom();
  }

  void _handleUserMessage(String query) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;
    if (_isSendingReply) return;

    _textCtrl.clear();

    if (_activeTab == 1) {
      // 💬 LIVE CHAT MODE: Send message directly to Admin ticket
      _sendLiveAdminReply(cleanQuery);
    } else {
      // 🤖 AI ASSISTANT MODE
      _addUserMessage(cleanQuery, isLiveChat: false);
      setState(() => _isTyping = true);

      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() => _isTyping = false);
        _processNlpQuery(cleanQuery.toLowerCase(), rawQuery: cleanQuery);
      });
    }
  }

  Future<void> _sendLiveAdminReply(String msg) async {
    if (_isSendingReply) return;
    _isSendingReply = true;

    // Optimistically add to UI so user sees instant feedback
    _addUserMessage(msg, isLiveChat: true);

    try {
      if (_activeTicket == null) {
        // Automatically create a new live support ticket
        final ticketData = {
          'userType': 'DeliveryPartner',
          'userId': _driverId,
          'userName': _driverName.isNotEmpty ? _driverName : 'Delivery Partner',
          'userPhone': _driverPhone.isNotEmpty ? _driverPhone : '9876543210',
          'subject': 'Live Support Chat - $_driverName',
          'category': 'General Support',
          'issueType': 'General Support',
          'priority': 'High',
          'message': msg,
          if (widget.relatedOrderId != null) 'orderDisplayId': widget.relatedOrderId,
        };

        final created = await DeliveryAuthService.createSupportTicket(ticketData);
        if (created != null && mounted) {
          setState(() {
            _activeTicket = created;
          });
          HapticFeedback.mediumImpact();
        }
      } else {
        final ticketId = _activeTicket!['_id'];
        await DeliveryAuthService.replyToTicket(ticketId, _driverName, msg);
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Error sending live admin reply: $e');
    } finally {
      if (mounted) {
        _isSendingReply = false;
      }
    }
  }

  void _processNlpQuery(String q, {required String rawQuery}) {
    // 1. SALARY / PAYOUT / SETTLEMENT / MONEY
    if (q.contains('salary') ||
        q.contains('payout') ||
        q.contains('settle') ||
        q.contains('panam') ||
        q.contains('kasu') ||
        q.contains('credit') ||
        q.contains('bank') ||
        q.contains('varala')) {
      _addBotMessage(
        '💳 **Weekly Settlement & Payout Policy (சம்பளம் விபரம்)**:\n\n'
        '1. **Settlement Day**: Weekly payouts are automatically transferred every **Tuesday by 8:00 PM** to your linked Bank Account / UPI.\n'
        '2. **Daily Earnings**: Daily trips + tips + surge bonus get calculated nightly at 11:59 PM.\n'
        '3. If your payout has not arrived after Tuesday, our Admin Finance Desk can check and trigger immediate disbursement.',
        cardType: 'PAYOUT_CARD',
        cardData: {
          'nextSettlement': 'Tuesday 8:00 PM',
          'status': 'Processing Active',
        },
        actions: [
          ChatAction(
            label: 'View Earnings Breakdown',
            icon: Icons.account_balance_wallet_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderEarningsScreen())),
          ),
          ChatAction(
            label: 'Auto-Raise Salary Ticket to Admin',
            icon: Icons.send_rounded,
            isPrimary: true,
            onTap: () => _autoRaiseTicketAndSwitch(
              category: 'Payout & Weekly Settlement',
              subject: 'Payout & Weekly Settlement - $_driverName',
              message: rawQuery,
            ),
          ),
        ],
      );
      return;
    }

    // 2. CUSTOMER NOT REACHABLE / PHONE SWITCH OFF / NOT ANSWERING
    if (q.contains('customer') ||
        q.contains('call') ||
        q.contains('phone') ||
        q.contains('edukala') ||
        q.contains('reach') ||
        q.contains('attend') ||
        q.contains('switch off') ||
        q.contains('door')) {
      _addBotMessage(
        '📞 **Customer Unreachable SOP (வாடிக்கையாளர் அழைப்பு உதவி)**:\n\n'
        '1. **Call Customer**: Attempt to call at least **2 times** using the masked app call button.\n'
        '2. **Wait Timer**: Wait at the customer doorstep/location for at least **5 to 8 minutes**.\n'
        '3. **Instant Admin Authorization**: Tap below to auto-notify Admin to cancel/return the order without penalty.',
        cardType: 'CUSTOMER_UNREACHABLE_CARD',
        cardData: {
          'orderId': widget.relatedOrderId ?? 'Active Order',
          'waitTime': '5 Minutes',
        },
        actions: [
          ChatAction(
            label: 'Notify Admin (Customer Unreachable)',
            icon: Icons.phone_disabled_rounded,
            isPrimary: true,
            onTap: () => _autoRaiseTicketAndSwitch(
              category: 'Customer Not Reachable',
              subject: 'Customer Unreachable on Order #${widget.relatedOrderId ?? 'Current'}',
              message: 'Attempted call 2 times at delivery location. Customer phone switch off or unanswered.',
            ),
          ),
          ChatAction(
            label: 'Call Helpline',
            icon: Icons.phone_in_talk_rounded,
            onTap: () => _makePhoneCall('18001234567'),
          ),
        ],
      );
      return;
    }

    // 3. VEHICLE BREAKDOWN / PUNCTURE / ACCIDENT / SOS
    if (q.contains('breakdown') ||
        q.contains('puncture') ||
        q.contains('vandi') ||
        q.contains('bike') ||
        q.contains('accident') ||
        q.contains('sos') ||
        q.contains('emergency') ||
        q.contains('repair') ||
        q.contains('petrol')) {
      _addBotMessage(
        '🚨 **Emergency & Roadside Safety Assist (அவசர உதவி)**:\n\n'
        '• Move your bike to a safe zone immediately.\n'
        '• For medical emergencies or accidents, trigger **SOS Emergency** below.\n'
        '• If you have an active order, our Dispatch Team will automatically re-assign it to another partner without any rating penalty.',
        cardType: 'SOS_CARD',
        actions: [
          ChatAction(
            label: 'Open SOS Safety Center',
            icon: Icons.emergency_rounded,
            color: const Color(0xFFDC2626),
            isPrimary: true,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyCenterScreen())),
          ),
          ChatAction(
            label: 'Report Vehicle Breakdown to Admin',
            icon: Icons.two_wheeler_rounded,
            onTap: () => _autoRaiseTicketAndSwitch(
              category: 'Vehicle Breakdown & Duty',
              subject: 'Vehicle Breakdown on Duty - $_driverName',
              message: 'Vehicle breakdown/puncture on duty. Requesting shift pause or order re-assignment.',
            ),
          ),
        ],
      );
      return;
    }

    // 4. STORE CLOSED / LOCATION WRONG
    if (q.contains('store') ||
        q.contains('shop') ||
        q.contains('closed') ||
        q.contains('moodi') ||
        q.contains('location') ||
        q.contains('map') ||
        q.contains('thappa') ||
        q.contains('wrong')) {
      _addBotMessage(
        '🏬 **Store Closed / Wrong Location Incident**:\n\n'
        '1. Verify the merchant name board at the destination coordinates.\n'
        '2. If the store is closed, tap below to report it directly to Admin.\n'
        '3. You will receive **travel distance compensation** after instant verification.',
        actions: [
          ChatAction(
            label: 'Report Store Closed to Admin',
            icon: Icons.wrong_location_rounded,
            isPrimary: true,
            onTap: () => _autoRaiseTicketAndSwitch(
              category: 'Store Closed / Wrong Location',
              subject: 'Store Closed at Pickup Location',
              message: 'Merchant store is closed upon arrival at pickup location.',
            ),
          ),
        ],
      );
      return;
    }

    // 5. INCENTIVES / BONUS / TARGET
    if (q.contains('incentive') ||
        q.contains('bonus') ||
        q.contains('target') ||
        q.contains('extra') ||
        q.contains('tier') ||
        q.contains('perk')) {
      _addBotMessage(
        '🏆 **Daily & Weekly Incentive Rewards**:\n\n'
        '• **Lunch Peak**: ₹20 Extra per order (12:30 PM - 3:00 PM)\n'
        '• **Dinner Peak**: ₹30 Extra per order (7:00 PM - 10:30 PM)\n'
        '• **Milestone 1**: 10 Orders Completed = ₹150 Cash Bonus\n'
        '• **Milestone 2**: 18 Orders Completed = ₹350 Cash Bonus\n'
        '• **Milestone 3**: 25 Orders Completed = ₹600 Super Bonus',
        actions: [
          ChatAction(
            label: 'View Live Earnings & Tiers',
            icon: Icons.workspace_premium_rounded,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RiderEarningsScreen())),
          ),
        ],
      );
      return;
    }

    // 6. CONNECT TO LIVE ADMIN / HUMAN SUPPORT
    if (q.contains('admin') ||
        q.contains('human') ||
        q.contains('agent') ||
        q.contains('person') ||
        q.contains('pesanum') ||
        q.contains('support') ||
        q.contains('live')) {
      _addBotMessage(
        '👨‍💼 **Connecting to Live Super Admin Desk...**\n\n'
        'I am transferring you to a live support executive right now. Your ticket will appear on the Admin Control Screen.',
        actions: [
          ChatAction(
            label: 'Open Live Admin Chat Desk',
            icon: Icons.headset_mic_rounded,
            isPrimary: true,
            onTap: () => _autoRaiseTicketAndSwitch(
              category: 'General Support',
              subject: 'Live Assistance Request - $_driverName',
              message: rawQuery,
            ),
          ),
        ],
      );
      return;
    }

    // DEFAULT FALLBACK
    _addBotMessage(
      'Got it. I understand you are reporting:\n\n> "$rawQuery"\n\n'
      'Would you like me to automatically create a **Live Incident Ticket** and notify the Admin Desk?',
      actions: [
        ChatAction(
          label: 'Yes, Send to Admin Support Desk',
          icon: Icons.send_rounded,
          isPrimary: true,
          onTap: () => _autoRaiseTicketAndSwitch(
            category: 'General Support',
            subject: 'Rider Query: $rawQuery',
            message: rawQuery,
          ),
        ),
        ChatAction(
          label: 'Talk to Live Agent',
          icon: Icons.support_agent_rounded,
          onTap: () => _switchToLiveChat(autoCreate: true),
        ),
      ],
    );
  }

  Future<void> _autoRaiseTicketAndSwitch({
    required String category,
    required String subject,
    required String message,
  }) async {
    HapticFeedback.mediumImpact();

    final ticketData = {
      'userType': 'DeliveryPartner',
      'userId': _driverId,
      'userName': _driverName.isNotEmpty ? _driverName : 'Delivery Partner',
      'userPhone': _driverPhone.isNotEmpty ? _driverPhone : '9876543210',
      'subject': subject,
      'category': category,
      'issueType': category,
      'priority': 'High',
      'message': message,
      if (widget.relatedOrderId != null) 'orderDisplayId': widget.relatedOrderId,
    };

    final created = await DeliveryAuthService.createSupportTicket(ticketData);

    if (created != null && mounted) {
      setState(() {
        _activeTicket = created;
        _activeTab = 1; // Switch to Live Chat tab
      });

      _populateLiveChatFromTicket(created);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ticket #${created['ticketNumber'] ?? 'TK'} Dispatched to Admin Desk!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _switchToLiveChat({bool autoCreate = false}) async {
    if (_activeTicket == null && autoCreate) {
      await _autoRaiseTicketAndSwitch(
        category: 'General Support',
        subject: 'Live Chat Request - $_driverName',
        message: 'Rider initiated live support chat session.',
      );
    } else {
      setState(() => _activeTab = 1);
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSegmentedTabHeader(),
          if (_activeTicket != null) _buildActiveTicketPillBar(),
          Expanded(
            child: _activeTab == 0 ? _buildAiAssistantView() : _buildLiveAdminChatView(),
          ),
          if (_activeTab == 0) _buildQuickSuggestionBar(),
          _buildChatInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.darkText),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FLEET SUPPORT HUB',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 0.5,
                    color: AppTheme.darkText,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Live 24/7 Control Room Sync',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFEF4444), size: 22),
          tooltip: 'SOS Helpline',
          onPressed: () => _makePhoneCall('18001234567'),
        ),
        IconButton(
          icon: const Icon(Icons.confirmation_number_outlined, color: AppTheme.darkText, size: 22),
          tooltip: 'Help Center & Tickets',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen())),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppTheme.borderLight, height: 1),
      ),
    );
  }

  Widget _buildSegmentedTabHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeTab = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _activeTab == 0 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _activeTab == 0
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.smart_toy_rounded,
                        size: 16,
                        color: _activeTab == 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AI ASSISTANT',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _activeTab == 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => _switchToLiveChat(autoCreate: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _activeTab == 1 ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _activeTab == 1
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.support_agent_rounded,
                        size: 16,
                        color: _activeTab == 1 ? const Color(0xFF059669) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LIVE ADMIN DESK',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: _activeTab == 1 ? const Color(0xFF059669) : const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (_activeTicket != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTicketPillBar() {
    final ticketNum = _activeTicket!['ticketNumber'] ?? 'TK-LIVE';
    final status = (_activeTicket!['status'] ?? 'Open').toString().toUpperCase();
    final category = _activeTicket!['category'] ?? 'Support';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.07),
        border: Border(bottom: BorderSide(color: const Color(0xFF4F46E5).withValues(alpha: 0.12))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$ticketNum',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$category • $status',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF3730A3)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_isLoadingLiveChat)
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)))
          else
            InkWell(
              onTap: () => _syncActiveTicketReplies(),
              child: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF4F46E5)),
            ),
        ],
      ),
    );
  }

  Widget _buildAiAssistantView() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _aiMessages.length + (_isTyping ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _aiMessages.length && _isTyping) {
          return _buildTypingIndicator();
        }
        final msg = _aiMessages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildLiveAdminChatView() {
    if (_activeTicket == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded, size: 48, color: Color(0xFF4F46E5)),
              ),
              const SizedBox(height: 16),
              Text(
                'Direct Live Admin Chat',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.darkText),
              ),
              const SizedBox(height: 8),
              Text(
                'Type any message below to immediately open an incident ticket and chat live with Super Admin executives.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.lightText, height: 1.4),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _autoRaiseTicketAndSwitch(
                  category: 'General Support',
                  subject: 'Live Assistance - $_driverName',
                  message: 'Rider initiated live session.',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                icon: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                label: Text(
                  'CONNECT LIVE WITH ADMIN',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFECFDF5),
          child: Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF059669), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Super Admin Resolution Desk is connected. Messages sync in real-time.',
                  style: GoogleFonts.outfit(color: const Color(0xFF065F46), fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _liveMessages.length,
            itemBuilder: (context, index) {
              final msg = _liveMessages[index];
              return _buildMessageBubble(msg);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isMe = msg.sender == ChatSender.user;
    final isAdmin = msg.sender == ChatSender.admin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isAdmin
                          ? [const Color(0xFF059669), const Color(0xFF10B981)]
                          : [const Color(0xFF4F46E5), const Color(0xFF7C3AED)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isAdmin ? Icons.shield_rounded : Icons.smart_toy_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFF4F46E5)
                        : (isAdmin ? const Color(0xFFF0FDF4) : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isMe ? 0.08 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: isMe
                        ? null
                        : Border.all(
                            color: isAdmin ? const Color(0xFF86EFAC) : AppTheme.borderLight,
                          ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAdmin) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.security_rounded, size: 12, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              'Admin Resolution Team',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      _formatRichText(msg.text, isMe),
                      if (msg.cardType != null) ...[
                        const SizedBox(height: 10),
                        _buildCustomCard(msg.cardType!, msg.cardData),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            _formatTime(msg.timestamp),
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              color: isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.lightText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.done_all_rounded, size: 13, color: Colors.white70),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (msg.actions != null && msg.actions!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.actions!.map((action) => _buildActionButton(action)).toList(),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05);
  }

  Widget _buildCustomCard(String cardType, Map<String, dynamic>? data) {
    if (cardType == 'PAYOUT_CARD') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF2563EB), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekly Settlement Cycle', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF1E40AF))),
                  Text('Next batch: Every Tuesday 8:00 PM', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF3B82F6))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (cardType == 'CUSTOMER_UNREACHABLE_CARD') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined, color: Color(0xFFD97706), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Doorstep Wait Timer (5 Mins)', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF92400E))),
                  Text('Wait at location before Admin cancellation.', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFB45309))),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox();
  }

  Widget _buildActionButton(ChatAction action) {
    final isPri = action.isPrimary;
    final btnColor = action.color ?? (isPri ? const Color(0xFF4F46E5) : Colors.white);

    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isPri ? btnColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPri ? btnColor : const Color(0xFF4F46E5).withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isPri ? btnColor : Colors.black).withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              action.icon,
              size: 14,
              color: isPri ? Colors.white : const Color(0xFF4F46E5),
            ),
            const SizedBox(width: 6),
            Text(
              action.label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isPri ? Colors.white : const Color(0xFF4F46E5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFF4F46E5),
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          delay: Duration(milliseconds: index * 180),
          duration: 400.ms,
          begin: const Offset(0.6, 0.6),
          end: const Offset(1.2, 1.2),
        );
  }

  Widget _buildQuickSuggestionBar() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickSuggestions.length,
        itemBuilder: (context, index) {
          final item = _quickSuggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              side: BorderSide(color: const Color(0xFF4F46E5).withValues(alpha: 0.18)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              avatar: Icon(item['icon'] as IconData, size: 14, color: const Color(0xFF4F46E5)),
              label: Text(
                item['label']!,
                style: GoogleFonts.outfit(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3730A3),
                ),
              ),
              onPressed: () => _handleUserMessage(item['query']!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatInputArea() {
    final isLive = _activeTab == 1;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: TextField(
                controller: _textCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _handleUserMessage,
                style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.darkText, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: isLive
                      ? 'Type message to Super Admin desk...'
                      : 'Ask question (Tamil / English)...',
                  hintStyle: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() => _isVoiceRecording = !_isVoiceRecording);
              if (_isVoiceRecording) {
                HapticFeedback.heavyImpact();
                _textCtrl.text = 'salary varala sir, payout eppo varum?';
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _isVoiceRecording ? const Color(0xFFEF4444) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(
                _isVoiceRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: _isVoiceRecording ? Colors.white : const Color(0xFF64748B),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _handleUserMessage(_textCtrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLive
                      ? [const Color(0xFF059669), const Color(0xFF10B981)]
                      : [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: (isLive ? const Color(0xFF059669) : const Color(0xFF4F46E5)).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatRichText(String text, bool isMe) {
    final textColor = isMe ? Colors.white : AppTheme.darkText;
    final spans = <TextSpan>[];

    final lines = text.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('• ') || line.startsWith('- ')) {
        spans.add(TextSpan(
          text: '$line\n',
          style: GoogleFonts.outfit(color: textColor, fontSize: 13.5, height: 1.4),
        ));
      } else if (line.contains('**')) {
        final parts = line.split('**');
        for (int j = 0; j < parts.length; j++) {
          if (j % 2 == 1) {
            spans.add(TextSpan(
              text: parts[j],
              style: GoogleFonts.outfit(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                height: 1.4,
              ),
            ));
          } else {
            spans.add(TextSpan(
              text: parts[j],
              style: GoogleFonts.outfit(
                color: textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ));
          }
        }
        spans.add(const TextSpan(text: '\n'));
      } else {
        spans.add(TextSpan(
          text: '$line\n',
          style: GoogleFonts.outfit(
            color: textColor,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ));
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
