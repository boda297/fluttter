import 'package:flutter/material.dart';
import '../services/api/news_api.dart';
import '../services/notification_service.dart';
import '../models/news_model.dart';
import '../utils/auth_helper.dart';
import '../widgets/skeleton_loader.dart';
import 'project_details_screen.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final NewsApi _newsApi = NewsApi();
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = true;
  List<NewsModel> _news = [];

  static const Color brandRed = Color(0xFFE50914);

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadNews();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
    } catch (e) {
      print('⚠️ Error initializing notifications in NewsScreen: $e');
      // Don't block the app if notifications fail
    }
  }

  Future<void> _loadNews() async {
    try {
      final news = await _newsApi.getAllNews();
      
      // Check for new news and send notifications
      await _notificationService.checkAndNotifyNewNews(news);
      
      if (mounted) {
        setState(() {
          _news = news;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            _buildAppBar(context),
            // Results header
            _buildResultsHeader(),
            // News list
            Expanded(
              child: _isLoading
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return const SkeletonNewsCard();
                      },
                    )
                  : _news.isEmpty
                      ? const Center(
                          child: Text(
                            'No news available',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : _buildNewsList(),
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
                'News',
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

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Results',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${_news.length} News)',
            style: const TextStyle(
              color: brandRed,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _news.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: NewsCard(
            news: _news[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailsScreen(
                    projectId: _news[index].projectId,
                  ),
                ),
              );
            },
            onRemindToggle: () async {
              final isAuth = await AuthHelper.requireAuth(context);
              if (!isAuth) return;
              
              final news = _news[index];
              if (news.isReminded) {
                await _newsApi.unremindNews(news.id);
              } else {
                await _newsApi.remindNews(news.id);
              }
              _loadNews();
            },
          ),
        );
      },
    );
  }
}

class NewsCard extends StatefulWidget {
  final NewsModel news;
  final VoidCallback onTap;
  final VoidCallback onRemindToggle;

  const NewsCard({
    super.key,
    required this.news,
    required this.onTap,
    required this.onRemindToggle,
  });

  @override
  State<NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<NewsCard> {
  bool _isReminded = false;
  final NewsApi _newsApi = NewsApi();

  @override
  void initState() {
    super.initState();
    _checkReminded();
  }

  Future<void> _checkReminded() async {
    final isReminded = await _newsApi.isNewsReminded(widget.news.id);
    if (mounted) {
      setState(() {
        _isReminded = isReminded;
      });
    }
  }

  Future<void> _toggleRemind() async {
    if (_isReminded) {
      await _newsApi.unremindNews(widget.news.id);
    } else {
      await _newsApi.remindNews(widget.news.id);
    }
    if (mounted) {
      setState(() {
        _isReminded = !_isReminded;
      });
    }
    widget.onRemindToggle();
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.news.gradientColors.map((c) {
      final hex = c.replaceAll('0x', '');
      return Color(int.parse(hex, radix: 16));
    }).toList();

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            // Background image if available
            if (widget.news.image.isNotEmpty)
              Positioned.fill(
                child: widget.news.isAsset
                    ? Image.asset(
                        widget.news.image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      )
                    : Image.network(
                        widget.news.image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
              ),
            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      gradientColors[0].withOpacity(0.8),
                      gradientColors[1].withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),
            // Project info overlay at top
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.news.title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.news.subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                  if (widget.news.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.news.description,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Bottom info bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.news.projectName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (widget.news.projectSubtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.news.projectSubtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Remind Me button
                    GestureDetector(
                      onTap: _toggleRemind,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isReminded
                                  ? Icons.notifications
                                  : Icons.notifications_outlined,
                              color: Colors.white.withOpacity(0.9),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Remind Me',
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
            ),
          ],
        ),
      ),
    );
  }
}

