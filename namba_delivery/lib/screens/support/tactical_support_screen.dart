import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart' as icons;
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

class TacticalSupportScreen extends StatefulWidget {
  const TacticalSupportScreen({super.key});

  @override
  State<TacticalSupportScreen> createState() => _TacticalSupportScreenState();
}

class _TacticalSupportScreenState extends State<TacticalSupportScreen> {
  final List<Map<String, dynamic>> _messages = [
    {'isMe': false, 'text': 'Hello! How can I assist you with your delivery today?', 'time': '12:04 PM'},
  ];
  final _msgCtrl = TextEditingController();

  void _sendMessage(String text) {
    if (text.isEmpty) return;
    setState(() {
      _messages.add({'isMe': true, 'text': text, 'time': '12:05 PM'});
    });
    _msgCtrl.clear();
    
    // Simulated support response
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _messages.add({'isMe': false, 'text': 'Got it. I\'m looking into this for you right now.', 'time': '12:05 PM'});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      appBar: AppBar(
        title: Column(
          children: [
            Text('SUPPORT LIAISON', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.5, color: AppTheme.darkText)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.accentGreen, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('REPRESENTATIVE ONLINE', style: GoogleFonts.outfit(fontSize: 9, color: AppTheme.accentGreen, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg['isMe'], msg['text'], msg['time']);
              },
            ),
          ),
          _buildQuickActionShortcuts(),
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(bool isMe, String text, String time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isMe ? Colors.white : AppTheme.lightBg.withValues(alpha: 1.0),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(24),
            topRight: const Radius.circular(24),
            bottomLeft: Radius.circular(isMe ? 24 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 24),
          ),
          boxShadow: isMe ? AppTheme.softShadow : null,
          border: isMe ? null : Border.all(color: AppTheme.darkText.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: GoogleFonts.outfit(
                color: AppTheme.darkText.withValues(alpha: 0.8),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(time, style: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildQuickActionShortcuts() {
    final actions = ['I\'M AT THE HUB', 'CUSTOMER NOT RESPONDING', 'TRAFFIC DELAY', 'ORDER PICKED UP'];
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _sendMessage(actions[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.softShadow,
                border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.1)),
              ),
              child: Center(
                child: Text(actions[index], style: GoogleFonts.outfit(color: AppTheme.primaryOrange, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: AppTheme.lightBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: GoogleFonts.outfit(color: AppTheme.darkText, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: GoogleFonts.outfit(color: AppTheme.lightText, fontSize: 14, fontWeight: FontWeight.w600),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _sendMessage(_msgCtrl.text),
            child: Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: AppTheme.primaryOrange.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: const Icon(icons.Iconsax.send_1_copy, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}
