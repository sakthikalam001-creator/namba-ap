import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ).animate(onPlay: (controller) => controller.repeat())
     .shimmer(
       duration: 1200.ms,
       color: isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.5),
     );
  }
}

class ShimmerStoreTile extends StatelessWidget {
  const ShimmerStoreTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF27272A) 
            : const Color(0xFFF4F4F5)),
      ),
      child: Row(
        children: [
          const ShimmerLoading(width: 64, height: 64, borderRadius: 16),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerLoading(width: 140, height: 16),
                const SizedBox(height: 8),
                const ShimmerLoading(width: 80, height: 10),
                const SizedBox(height: 16),
                Row(
                  children: const [
                    ShimmerLoading(width: 40, height: 12),
                    SizedBox(width: 16),
                    ShimmerLoading(width: 60, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
