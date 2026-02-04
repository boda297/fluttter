import 'package:flutter/material.dart';

class ProjectCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Color> gradientColors;
  final String? imageUrl;
  final String? imageAsset;
  final double width;
  final double height;
  final VoidCallback? onTap;
  final bool showPlayButton;

  const ProjectCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.gradientColors,
    this.imageUrl,
    this.imageAsset,
    this.width = 160,
    this.height = 200,
    this.onTap,
    this.showPlayButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or gradient
              if (imageAsset != null)
                Image.asset(
                  imageAsset!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                      ),
                    );
                  },
                )
              else if (imageUrl != null)
                Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradientColors,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                  ),
                ),
              // Gradient overlay for text visibility
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (showPlayButton)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RankedProjectCard extends StatelessWidget {
  final int rank;
  final String title;
  final List<Color> gradientColors;
  final String? imageAsset; // Local asset path
  final String? imageUrl; // Network image URL
  final VoidCallback? onTap;

  const RankedProjectCard({
    super.key,
    required this.rank,
    required this.title,
    required this.gradientColors,
    this.imageAsset,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 130,
        height: 170,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Outline number (behind - shifted as shadow effect)
            Positioned(
              left: 10,
              bottom: 5,
              child: Image.asset(
                'assets/top10/${rank}_outline.png',
                height: 75,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox();
                },
              ),
            ),
            // 2. Card with image (middle layer)
            Positioned(
              top: 0,
              right: 0,
              left: 40,
              bottom: 45,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageAsset != null
                      ? Image.asset(
                          imageAsset!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildGradientFallback();
                          },
                        )
                      : imageUrl != null
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return _buildGradientFallback();
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return _buildGradientFallback();
                              },
                            )
                          : _buildGradientFallback(),
                ),
              ),
            ),
            // 3. Filled number (in front)
            Positioned(
              left: 2,
              bottom: 15,
              child: Image.asset(
                'assets/top10/$rank.png',
                height: 75,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class FeaturedProjectCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? label;
  final List<Color> gradientColors;
  final VoidCallback? onWatch;

  const FeaturedProjectCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.label,
    required this.gradientColors,
    this.onWatch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Decorative shapes
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (label != null) ...[
                  Text(
                    label!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                // Watch button
                GestureDetector(
                  onTap: onWatch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.black,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Watch',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectListItem extends StatelessWidget {
  final String projectId;
  final String developerName;
  final String projectName;
  final List<Color> gradientColors;
  final bool isSaved;
  final String? imageUrl;
  final String? imageAsset;
  final VoidCallback? onWatch;
  final VoidCallback? onBookmark;
  final VoidCallback? onShare;
  final VoidCallback? onTap;

  const ProjectListItem({
    super.key,
    required this.projectId,
    required this.developerName,
    required this.projectName,
    required this.gradientColors,
    this.isSaved = false,
    this.imageUrl,
    this.imageAsset,
    this.onWatch,
    this.onBookmark,
    this.onShare,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Thumbnail
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradientColors,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildThumbnailImage(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  developerName,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  projectName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                // Watch button
                GestureDetector(
                  onTap: onWatch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Watch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Action buttons
          Column(
            children: [
              IconButton(
                icon: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_outline,
                  color: isSaved ? const Color(0xFFE50914) : Colors.white.withOpacity(0.6),
                  size: 22,
                ),
                onPressed: onBookmark,
              ),
              IconButton(
                icon: Icon(
                  Icons.share_outlined,
                  color: Colors.white.withOpacity(0.6),
                  size: 22,
                ),
                onPressed: onShare,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailImage() {
    print('🖼️ ProjectListItem: Building thumbnail for "$projectName"');
    print('   imageAsset: $imageAsset');
    print('   imageUrl: $imageUrl');
    
    if (imageAsset != null) {
      print('   Using Image.asset: $imageAsset');
      return Image.asset(
        imageAsset!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('⚠️ Error loading asset image: $imageAsset - $error');
          return _buildThumbnailPlaceholder();
        },
      );
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      print('   Using Image.network: $imageUrl');
      return Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            print('✅ Image loaded successfully: $imageUrl');
            return child;
          }
          return _buildThumbnailPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          print('⚠️ Error loading network image: $imageUrl - $error');
          return _buildThumbnailPlaceholder();
        },
      );
    } else {
      print('⚠️ No image URL/Asset available, using placeholder');
      return _buildThumbnailPlaceholder();
    }
  }

  Widget _buildThumbnailPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Center(
        child: Text(
          projectName.length > 8 ? projectName.substring(0, 8) : projectName,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
