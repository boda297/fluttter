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
    return [
      _buildParagraph(
        'By downloading, installing, or using the Orientation app, you agree to be '
        'bound by these Terms and Conditions. If you do not agree, please do not use '
        'the app.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Use of the App'),
      const SizedBox(height: 8),
      _buildParagraph(
        'Orientation provides access to curated video content, including short clips, '
        'episodes, and news. You may use the app for personal, non-commercial purposes '
        'only. You must not copy, redistribute, or misuse any content or features.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Account Responsibility'),
      const SizedBox(height: 8),
      _buildParagraph(
        'You are responsible for maintaining the confidentiality of your account '
        'credentials. Any activity under your account is your responsibility. You must '
        'notify us promptly of any unauthorized use.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('User Conduct'),
      const SizedBox(height: 8),
      _buildParagraph(
        'You agree not to use the app to violate any laws, infringe on others\' rights, '
        'or distribute harmful or inappropriate content. We reserve the right to '
        'suspend or terminate accounts that violate these terms.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Intellectual Property'),
      const SizedBox(height: 8),
      _buildParagraph(
        'All content, branding, and materials within the app are owned by Orientation '
        'or its licensors. You may not reproduce, modify, or create derivative works '
        'without express permission.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Disclaimer'),
      const SizedBox(height: 8),
      _buildParagraph(
        'The app and its content are provided "as is" without warranties of any kind. '
        'We do not guarantee uninterrupted access, accuracy of content, or suitability '
        'for any particular purpose.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Limitation of Liability'),
      const SizedBox(height: 8),
      _buildParagraph(
        'To the fullest extent permitted by law, Orientation shall not be liable for '
        'any indirect, incidental, special, or consequential damages arising from your '
        'use of the app.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Changes'),
      const SizedBox(height: 8),
      _buildParagraph(
        'We may update these Terms and Conditions from time to time. Continued use of '
        'the app after changes constitutes acceptance of the updated terms.',
      ),
      const SizedBox(height: 24),
      _buildSectionTitle('Contact'),
      const SizedBox(height: 8),
      _buildParagraph('For questions about these terms, contact us at:'),
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
