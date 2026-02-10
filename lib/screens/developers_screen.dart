import 'package:flutter/material.dart';
import '../services/api/home_api.dart';
import '../models/developer_model.dart';

class DevelopersScreen extends StatefulWidget {
  const DevelopersScreen({super.key});

  @override
  State<DevelopersScreen> createState() => _DevelopersScreenState();
}

class _DevelopersScreenState extends State<DevelopersScreen> {
  final HomeApi _homeApi = HomeApi();
  List<DeveloperModel> _developers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevelopers();
  }

  Future<void> _loadDevelopers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _homeApi.getDevelopers();
      if (mounted) {
        setState(() {
          _developers = list;
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
          'Developers',
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
                onPressed: _loadDevelopers,
                child: const Text('Retry', style: TextStyle(color: Color(0xFFE50914))),
              ),
            ],
          ),
        ),
      );
    }
    if (_developers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_outlined, color: Colors.white.withOpacity(0.3), size: 64),
            const SizedBox(height: 16),
            Text(
              'No developers yet',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
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
                  text: '(${_developers.length} Developer${_developers.length == 1 ? '' : 's'})',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              itemCount: _developers.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (context, index) {
                return DeveloperCard(model: _developers[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DeveloperCard extends StatelessWidget {
  final DeveloperModel model;

  const DeveloperCard({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          _buildLogo(),
          const SizedBox(height: 8),
          Text(
            model.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (model.projectsCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${model.projectsCount} project${model.projectsCount == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLogo() {
    final hasUrl = model.logo.isNotEmpty && model.logo.startsWith('http');
    final hasAsset = model.isAsset && model.logo.isNotEmpty;

    if (hasUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          model.logo,
          height: 72,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    if (hasAsset) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          model.logo,
          height: 72,
          width: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Icon(Icons.business, color: Colors.white.withOpacity(0.3), size: 36),
    );
  }
}
