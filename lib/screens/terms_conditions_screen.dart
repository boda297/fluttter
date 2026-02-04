import 'package:flutter/material.dart';
import '../widgets/orientation_logo.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            _buildAppBar(context),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo
                    const Center(child: OrientationLogo()),
                    const SizedBox(height: 32),
                    // Section title
                    const Text(
                      'Our Terms',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Content paragraphs
                    ..._buildContentParagraphs(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.chevron_left,
              color: Colors.white,
              size: 28,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Terms and Conditions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  List<Widget> _buildContentParagraphs() {
    const loremIpsum = '''Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum''';

    const shortParagraph = '''Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book.''';

    return [
      _buildParagraph(loremIpsum),
      const SizedBox(height: 16),
      _buildParagraph(shortParagraph),
      const SizedBox(height: 16),
      _buildParagraph(loremIpsum),
      const SizedBox(height: 16),
      _buildParagraph(shortParagraph),
    ];
  }

  Widget _buildParagraph(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 13,
        height: 1.6,
      ),
    );
  }
}

