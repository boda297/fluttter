import 'package:flutter/material.dart';
import '../widgets/orientation_logo.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

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
                      'About Us',
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
                'About Us',
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
        'Orientation is a modern mobile platform built for discovering, learning, '
        'and staying up to date through high-quality curated content. The app brings '
        'together short-form clips and full-length episodes in one smooth experience, '
        'helping users explore topics quickly or dive deeper when they want more detail. '
        'Content is organized into clear sections and collections, making it easy to '
        'browse by interest, follow trending items, and find something valuable in seconds.',
      ),
      const SizedBox(height: 16),
      _buildParagraph(
        'With Orientation, you can explore projects and episodes, watch engaging '
        'reels-style videos, and keep track of what you\'ve already viewed so you can '
        'continue watching right where you left off. The experience is designed to feel '
        'fast and intuitive: discover new content from the home feed, search by keywords, '
        'and open detailed pages that provide context, media, and related items. Whether '
        'you prefer short clips for quick inspiration or longer episodes for focused '
        'learning, the app supports both styles of consumption.',
      ),
      const SizedBox(height: 16),
      _buildParagraph(
        'Orientation also includes a news section so users can stay connected to the '
        'latest updates, announcements, and highlights. For those who enjoy curated picks, '
        'Top 10 lists surface the most relevant and popular items in a simple, visual way. '
        'You can save favorites to return to later, creating a personal library of content '
        'you care about.',
      ),
      const SizedBox(height: 16),
      _buildParagraph(
        'The app supports secure authentication and common account flows such as login, '
        'signup, password recovery, and verification, ensuring a reliable and user-friendly '
        'onboarding process. After signing in, users can manage basic account details and '
        'enjoy personalized features like saved content and watch history.',
      ),
      const SizedBox(height: 16),
      _buildParagraph(
        'The interface is clean, modern, and mobile-first, built with a focus on usability '
        'and performance. Smooth navigation, clear visual hierarchy, and responsive layouts '
        'make Orientation comfortable to use on a wide range of devices. Media playback is '
        'optimized for an enjoyable viewing experience, and the overall design encourages '
        'exploration without feeling overwhelming.',
      ),
      const SizedBox(height: 16),
      _buildParagraph(
        'Beyond simple browsing, Orientation is designed to help users build a routine '
        'around meaningful content. The "continue watching" experience reduces friction by '
        'remembering progress, while saved items let users create a personal queue for later '
        'viewing. This makes the app useful in both quick sessions—like a few minutes of '
        'scrolling through clips—and longer sessions, where users can watch full episodes '
        'or explore a complete project series.',
      ),
      const SizedBox(height: 16),
      _buildParagraph(
        'Orientation can serve different audiences and goals. For learners, it\'s a '
        'structured way to move from bite-sized clips into deeper materials. For fans of '
        'entertainment and trends, it\'s a fast way to catch highlights, share moments, '
        'and keep up with what\'s popular. For anyone interested in updates, the news feed '
        'provides a steady stream of fresh information inside the same app, without forcing '
        'users to jump between multiple platforms.',
      ),
      const SizedBox(height: 16),
      _buildParagraph(
        'The content presentation focuses on clarity: strong thumbnails, readable titles, '
        'and organized sections that help users decide quickly. Search and filtering make '
        'discovery easier, while detailed screens help users understand what they are '
        'watching and what to explore next. The app\'s navigation is designed to be '
        'familiar and consistent, so users always know how to move between home, clips, '
        'projects, saved items, and account settings.',
      ),
      const SizedBox(height: 16),
      _buildParagraph(
        'Reliability and user trust are key priorities. Authentication and verification '
        'flows are built to be straightforward, with clear feedback during sign-in and '
        'recovery steps. Account screens provide essential details without clutter, so '
        'users can confidently manage their profile and get back to content quickly.',
      ),
      const SizedBox(height: 16),
      _buildParagraph(
        'Orientation is ideal for users who want an all-in-one destination for curated '
        'video content, structured learning, and timely updates—helping them stay informed, '
        'entertained, and engaged anytime, anywhere.',
      ),
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
