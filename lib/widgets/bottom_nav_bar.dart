import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const Color brandRed = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                iconPath: 'assets/icons_bottom_navigation_bar/home.png',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                iconPath: 'assets/icons_bottom_navigation_bar/clips.png',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                iconPath: 'assets/icons_bottom_navigation_bar/new.png',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                iconPath: 'assets/icons_bottom_navigation_bar/account.png',
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String iconPath;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.iconPath,
    required this.isActive,
    required this.onTap,
  });

  static const Color brandRed = Color(0xFFE50914);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Image.asset(
          iconPath,
          width: 28,
          height: 28,
          color: isActive ? brandRed : Colors.white,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }
}

