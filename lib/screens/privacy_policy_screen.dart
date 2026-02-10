import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
                  children: [
                    // Policy icon
                    _buildPolicyIcon(),
                    const SizedBox(height: 24),
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
                'Privacy Policy',
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

  Widget _buildPolicyIcon() {
    return Image.asset(
      'assets/images/image_25.png',
      width: 154,
      height: 154,
      fit: BoxFit.contain,
    );
  }

  List<Widget> _buildContentParagraphs() {
    return [
      _buildParagraph(
        'This app respects your privacy and is committed to protecting your personal information.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Information Collection'),
      const SizedBox(height: 8),
      _buildParagraph(
        'We do not collect personal information such as your name, email, or phone number.',
      ),
      const SizedBox(height: 8),
      _buildParagraph(
        'The app may collect anonymous usage data or crash reports to improve performance.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('How We Use Data'),
      const SizedBox(height: 8),
      _buildParagraph('Collected information is used only to:'),
      const SizedBox(height: 8),
      _buildBulletPoint('Improve app stability'),
      _buildBulletPoint('Fix errors'),
      _buildBulletPoint('Enhance user experience'),
      const SizedBox(height: 24),
      _buildSectionTitle('Third-Party Services'),
      const SizedBox(height: 8),
      _buildParagraph(
        'The app may use services such as Google Play Services or Firebase which may collect anonymous data according to their own privacy policies.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Data Security'),
      const SizedBox(height: 8),
      _buildParagraph(
        'We take reasonable measures to protect your data from unauthorized access.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Changes'),
      const SizedBox(height: 8),
      _buildParagraph(
        'This policy may be updated from time to time.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Contact'),
      const SizedBox(height: 8),
      _buildParagraph('For any questions, contact us at:'),
      const SizedBox(height: 8),
      _buildParagraph('marketing@orientationre.com'),
    ];
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 13,
              height: 1.6,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
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
