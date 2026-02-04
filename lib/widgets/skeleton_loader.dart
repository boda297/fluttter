import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Shimmer effect widget for skeleton loading
class Shimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;
  final Duration period;

  const Shimmer({
    super.key,
    required this.child,
    this.baseColor = const Color(0xFF2A2A2A),
    this.highlightColor = const Color(0xFF3A3A3A),
    this.period = const Duration(milliseconds: 1500),
  });

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.period,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0.0),
              end: Alignment(1.0 + _controller.value * 2, 0.0),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Skeleton box widget
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? color;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color ?? const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Skeleton for clip/reel item
class SkeletonClipItem extends StatelessWidget {
  const SkeletonClipItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Video placeholder
          const SkeletonBox(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),
          // Bottom info section
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(
                    width: 200,
                    height: 20,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 8),
                  const SkeletonBox(
                    width: 150,
                    height: 16,
                    borderRadius: 4,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SkeletonBox(
                        width: 60,
                        height: 60,
                        borderRadius: 30,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: SkeletonBox(
                          height: 16,
                          borderRadius: 4,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Action buttons (right side)
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                const SkeletonBox(
                  width: 50,
                  height: 50,
                  borderRadius: 25,
                ),
                const SizedBox(height: 18),
                const SkeletonBox(
                  width: 50,
                  height: 50,
                  borderRadius: 25,
                ),
                const SizedBox(height: 18),
                const SkeletonBox(
                  width: 50,
                  height: 50,
                  borderRadius: 25,
                ),
                const SizedBox(height: 18),
                const SkeletonBox(
                  width: 50,
                  height: 50,
                  borderRadius: 25,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for project card
class SkeletonProjectCard extends StatelessWidget {
  final bool isLarge;

  const SkeletonProjectCard({
    super.key,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLarge) {
      return Container(
        margin: const EdgeInsets.only(right: 16),
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(
              width: double.infinity,
              height: 200,
              borderRadius: 12,
            ),
            const SizedBox(height: 12),
            const SkeletonBox(
              width: 200,
              height: 18,
              borderRadius: 4,
            ),
            const SizedBox(height: 8),
            const SkeletonBox(
              width: 150,
              height: 16,
              borderRadius: 4,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SkeletonBox(
                  width: 80,
                  height: 16,
                  borderRadius: 4,
                ),
                const SizedBox(width: 8),
                const SkeletonBox(
                  width: 60,
                  height: 16,
                  borderRadius: 4,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 160,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(
            width: double.infinity,
            height: 80,
            borderRadius: 12,
          ),
          const SizedBox(height: 6),
          const SkeletonBox(
            width: 120,
            height: 12,
            borderRadius: 4,
          ),
          const SizedBox(height: 3),
          const SkeletonBox(
            width: 80,
            height: 9,
            borderRadius: 4,
          ),
        ],
      ),
    );
  }
}

/// Skeleton for news card
class SkeletonNewsCard extends StatelessWidget {
  const SkeletonNewsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(
            width: 100,
            height: 100,
            borderRadius: 8,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                const SkeletonBox(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 4),
                const SkeletonBox(
                  width: 150,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 12),
                const SkeletonBox(
                  width: 80,
                  height: 12,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for episode item
class SkeletonEpisodeItem extends StatelessWidget {
  const SkeletonEpisodeItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SkeletonBox(
            width: 80,
            height: 60,
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(
                  width: double.infinity,
                  height: 16,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                const SkeletonBox(
                  width: 120,
                  height: 14,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
          const SkeletonBox(
            width: 40,
            height: 40,
            borderRadius: 20,
          ),
        ],
      ),
    );
  }
}

/// Skeleton for project details header
class SkeletonProjectHeader extends StatelessWidget {
  const SkeletonProjectHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SkeletonBox(
          width: double.infinity,
          height: 300,
          borderRadius: 0,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(
                width: 250,
                height: 24,
                borderRadius: 4,
              ),
              const SizedBox(height: 8),
              const SkeletonBox(
                width: 180,
                height: 18,
                borderRadius: 4,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const SkeletonBox(
                    width: 100,
                    height: 16,
                    borderRadius: 4,
                  ),
                  const SizedBox(width: 16),
                  const SkeletonBox(
                    width: 100,
                    height: 16,
                    borderRadius: 4,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

