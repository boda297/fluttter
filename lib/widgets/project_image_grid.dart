import 'package:flutter/material.dart';

class ProjectImageGrid extends StatelessWidget {
  const ProjectImageGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: 12,
          itemBuilder: (context, index) {
            return ProjectThumbnail(index: index);
          },
        );
      },
    );
  }
}

class ProjectThumbnail extends StatelessWidget {
  final int index;

  const ProjectThumbnail({
    super.key,
    required this.index,
  });

  // Project data for the grid
  static const List<ProjectData> projects = [
    ProjectData(
      name: '',
      gradient: [Color(0xFF1a3a52), Color(0xFF2d5a7b)],
      hasBoat: true,
    ),
    ProjectData(
      name: 'OC',
      gradient: [Color(0xFF8B7355), Color(0xFF6B5344)],
      isLogo: true,
    ),
    ProjectData(
      name: '',
      gradient: [Color(0xFF3d3d3d), Color(0xFF2a2a2a)],
      hasBuilding: true,
    ),
    ProjectData(
      name: 'WEST',
      gradient: [Color(0xFF1e3a4c), Color(0xFF2d4a5c)],
      subtitle: 'YOUR WAY',
    ),
    ProjectData(
      name: '',
      gradient: [Color(0xFF87CEEB), Color(0xFF4A90A4)],
      hasWater: true,
    ),
    ProjectData(
      name: 'masaya',
      gradient: [Color(0xFF2F4F4F), Color(0xFF1a3535)],
      isScript: true,
    ),
    ProjectData(
      name: 'TAWNY',
      gradient: [Color(0xFF4a6741), Color(0xFF3a5731)],
    ),
    ProjectData(
      name: '',
      gradient: [Color(0xFF5a4a3a), Color(0xFF4a3a2a)],
      hasApartment: true,
    ),
    ProjectData(
      name: 'LVERS',
      gradient: [Color(0xFF2a2a2a), Color(0xFF1a1a1a)],
      subtitle: 'NORTH COAST',
    ),
    ProjectData(
      name: '',
      gradient: [Color(0xFF708090), Color(0xFF505860)],
      hasTower: true,
    ),
    ProjectData(
      name: '',
      gradient: [Color(0xFF87CEEB), Color(0xFF5DADE2)],
      hasResort: true,
    ),
    ProjectData(
      name: 'Seashore',
      gradient: [Color(0xFF1a3a52), Color(0xFF0d2535)],
      isScript: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final project = projects[index % projects.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: project.gradient,
        ),
      ),
      child: Stack(
        children: [
          // Simulated image pattern
          if (project.hasBoat) const _BoatScene(),
          if (project.hasBuilding) const _BuildingScene(),
          if (project.hasWater) const _WaterScene(),
          if (project.hasApartment) const _ApartmentScene(),
          if (project.hasTower) const _TowerScene(),
          if (project.hasResort) const _ResortScene(),
          // Project name overlay
          if (project.name.isNotEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    project.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: project.isLogo ? 28 : (project.isScript ? 18 : 14),
                      fontWeight: project.isScript ? FontWeight.w400 : FontWeight.w700,
                      fontStyle: project.isScript ? FontStyle.italic : FontStyle.normal,
                      letterSpacing: project.isScript ? 0 : 2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (project.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      project.subtitle!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ProjectData {
  final String name;
  final List<Color> gradient;
  final String? subtitle;
  final bool isLogo;
  final bool isScript;
  final bool hasBoat;
  final bool hasBuilding;
  final bool hasWater;
  final bool hasApartment;
  final bool hasTower;
  final bool hasResort;

  const ProjectData({
    required this.name,
    required this.gradient,
    this.subtitle,
    this.isLogo = false,
    this.isScript = false,
    this.hasBoat = false,
    this.hasBuilding = false,
    this.hasWater = false,
    this.hasApartment = false,
    this.hasTower = false,
    this.hasResort = false,
  });
}

// Decorative scene widgets to simulate project images
class _BoatScene extends StatelessWidget {
  const _BoatScene();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BoatPainter(),
      size: Size.infinite,
    );
  }
}

class _BoatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Water
    final waterPaint = Paint()
      ..color = const Color(0xFF1a5a7a)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4),
      waterPaint,
    );
    
    // Simple boat shape
    final boatPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.65)
      ..lineTo(size.width * 0.8, size.height * 0.65)
      ..lineTo(size.width * 0.7, size.height * 0.75)
      ..lineTo(size.width * 0.3, size.height * 0.75)
      ..close();
    canvas.drawPath(path, boatPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BuildingScene extends StatelessWidget {
  const _BuildingScene();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BuildingPainter(),
      size: Size.infinite,
    );
  }
}

class _BuildingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final buildingPaint = Paint()
      ..color = const Color(0xFF4a4a4a)
      ..style = PaintingStyle.fill;
    
    // Main building
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.3, size.height * 0.2, size.width * 0.4, size.height * 0.8),
      buildingPaint,
    );
    
    // Windows
    final windowPaint = Paint()
      ..color = const Color(0xFFFFD700).withOpacity(0.6)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      for (int j = 0; j < 3; j++) {
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.35 + j * size.width * 0.1,
            size.height * 0.25 + i * size.height * 0.12,
            size.width * 0.06,
            size.height * 0.08,
          ),
          windowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WaterScene extends StatelessWidget {
  const _WaterScene();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WaterPainter(),
      size: Size.infinite,
    );
  }
}

class _WaterPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Waves
    final wavePaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    for (int i = 0; i < 4; i++) {
      final path = Path();
      path.moveTo(0, size.height * (0.4 + i * 0.15));
      for (double x = 0; x < size.width; x += 20) {
        path.quadraticBezierTo(
          x + 10, size.height * (0.35 + i * 0.15),
          x + 20, size.height * (0.4 + i * 0.15),
        );
      }
      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ApartmentScene extends StatelessWidget {
  const _ApartmentScene();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ApartmentPainter(),
      size: Size.infinite,
    );
  }
}

class _ApartmentPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final buildingPaint = Paint()
      ..color = const Color(0xFF6a5a4a)
      ..style = PaintingStyle.fill;
    
    // Multiple buildings
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.1, size.height * 0.3, size.width * 0.25, size.height * 0.7),
      buildingPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.4, size.height * 0.15, size.width * 0.25, size.height * 0.85),
      buildingPaint..color = const Color(0xFF5a4a3a),
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.7, size.height * 0.4, size.width * 0.25, size.height * 0.6),
      buildingPaint..color = const Color(0xFF7a6a5a),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TowerScene extends StatelessWidget {
  const _TowerScene();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TowerPainter(),
      size: Size.infinite,
    );
  }
}

class _TowerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final towerPaint = Paint()
      ..color = const Color(0xFF607080)
      ..style = PaintingStyle.fill;
    
    // Tall tower
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.1, size.width * 0.3, size.height * 0.9),
      towerPaint,
    );
    
    // Top
    final topPath = Path()
      ..moveTo(size.width * 0.3, size.height * 0.1)
      ..lineTo(size.width * 0.5, 0)
      ..lineTo(size.width * 0.7, size.height * 0.1)
      ..close();
    canvas.drawPath(topPath, towerPaint..color = const Color(0xFF506070));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResortScene extends StatelessWidget {
  const _ResortScene();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ResortPainter(),
      size: Size.infinite,
    );
  }
}

class _ResortPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Beach/sand
    final sandPaint = Paint()
      ..color = const Color(0xFFE8D4A8)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      sandPaint,
    );
    
    // Palm tree
    final trunkPaint = Paint()
      ..color = const Color(0xFF8B4513)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.45, size.height * 0.4, size.width * 0.1, size.height * 0.35),
      trunkPaint,
    );
    
    // Leaves
    final leafPaint = Paint()
      ..color = const Color(0xFF228B22)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final angle = (i - 2) * 0.4;
      final path = Path()
        ..moveTo(size.width * 0.5, size.height * 0.4)
        ..quadraticBezierTo(
          size.width * (0.5 + angle * 0.3),
          size.height * 0.25,
          size.width * (0.5 + angle * 0.5),
          size.height * 0.35,
        );
      canvas.drawPath(path, leafPaint..style = PaintingStyle.stroke..strokeWidth = 8);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

