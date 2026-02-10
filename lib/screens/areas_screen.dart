import 'package:flutter/material.dart';
import '../services/api/home_api.dart';
import '../models/area_model.dart';
import '../utils/auth_helper.dart';
import 'projects_list_screen.dart';

class AreasScreen extends StatefulWidget {
  const AreasScreen({super.key});

  @override
  State<AreasScreen> createState() => _AreasScreenState();
}

class _AreasScreenState extends State<AreasScreen> {
  final HomeApi _homeApi = HomeApi();
  List<AreaModel> _areas = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  Future<void> _loadAreas() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    // Simulate API delay for better UX
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Hardcoded areas since API returns empty
    // Matches the list in HomeFeedScreen
    final areaNames = [
      'Madinaty',
      'Sheraton',
      'New Cairo',
      'North Coast',
      'New Capital',
      'Sidi Abdelrhman',
      'October',
      'Ras Alhekma',
      'Mostakbal City',
      'Maadi',
      '6th Settlement',
    ];

    try {
      final list = areaNames.map((name) => AreaModel(
        id: name.toLowerCase().replaceAll(' ', '_'),
        name: name,
        projectsCount: 0, // We could fetch this if needed, but 0 is safe for now
      )).toList();
      
      if (mounted) {
        setState(() {
          _areas = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Areas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white.withOpacity(0.5), size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadAreas,
                child: const Text('Retry', style: TextStyle(color: Color(0xFFE50914))),
              ),
            ],
          ),
        ),
      );
    }
    if (_areas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: Colors.white.withOpacity(0.3), size: 64),
            const SizedBox(height: 16),
            Text(
              'No areas available',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Areas will appear when the API provides them.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Results ',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                TextSpan(
                  text: '(${_areas.length} Area${_areas.length == 1 ? '' : 's'})',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              itemCount: _areas.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                return AreaCard(
                  area: _areas[index],
                  onTap: () async {
                    final area = _areas[index];
                    /*
                    // Optional: Require auth before viewing area projects? Home screen does.
                    final isAuth = await AuthHelper.requireAuth(context);
                    if (!isAuth) return;
                    */
                    
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectsListScreen(
                            title: 'Projects in ${area.name}',
                            areaName: area.name,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AreaCard extends StatelessWidget {
  final AreaModel area;
  final VoidCallback? onTap;

  const AreaCard({
    super.key, 
    required this.area,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            area.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (area.projectsCount > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${area.projectsCount} project${area.projectsCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
          if (area.country.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              area.country,
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
      ), // Container
    ); // GestureDetector
  }
}
