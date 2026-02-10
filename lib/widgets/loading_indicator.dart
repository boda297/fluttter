import 'package:flutter/material.dart';

class LoadingIndicator extends StatelessWidget {
  final double progress;

  const LoadingIndicator({
    super.key,
    required this.progress,
  });

  static const Color brandRed = Color(0xFFE50914);
  static const Color trackColor = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress bar
        LoadingProgressBar(progress: progress),
        const SizedBox(height: 16),
        // Loading text
        const LoadingText(),
      ],
    );
  }
}

class LoadingProgressBar extends StatelessWidget {
  final double progress;

  const LoadingProgressBar({
    super.key,
    required this.progress,
  });

  static const Color brandRed = Color(0xFFE50914);
  static const Color trackColor = Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: brandRed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LoadingText extends StatelessWidget {
  const LoadingText({super.key});

  static const Color brandRed = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Loading...',
      style: TextStyle(
        color: brandRed,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
    );
  }
}

