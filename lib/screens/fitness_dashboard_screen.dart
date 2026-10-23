import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'fitness_goals_screen.dart';

class FitnessDashboardScreen extends StatefulWidget {
  const FitnessDashboardScreen({super.key, this.onTabSelected});

  final ValueChanged<int>? onTabSelected;

  @override
  State<FitnessDashboardScreen> createState() => _FitnessDashboardScreenState();
}

class _FitnessDashboardScreenState extends State<FitnessDashboardScreen> {
  static const Color navy = Color(0xFF062D63);
  static const Color blue = Color(0xFF086AC7);
  static const Color lightBlue = Color(0xFFC2DFF2);
  static const Color paleBlue = Color(0xFFE5F4FF);
  static const Color white = Colors.white;
  static const TextStyle _smallActionLabelStyle = TextStyle(
    color: white,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
  static const TextStyle _personalBestLabelStyle = TextStyle(
    color: navy,
    fontSize: 12,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle _personalBestValueStyle = TextStyle(
    color: Colors.black,
    fontSize: 20,
  );

  int _selectedTab = 0;

  static const _consistencyData = [
    0.16,
    0.73,
    0.43,
    0.68,
    0.64,
    0.40,
    1.00,
    0.70,
    1.03,
  ];
  static const _personalBests = ['—', '—', '—', '—'];

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
    widget.onTabSelected?.call(index);
  }

  Future<void> _openGoals() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FitnessGoalsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildHeader(),
                          const SizedBox(height: 28),
                          _buildPlannedWorkout(),
                          const SizedBox(height: 24),
                          _buildConsistency(),
                          const SizedBox(height: 24),
                          _buildPersonalBests(),
                          const SizedBox(height: 20),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _headingStyle(double size) {
    return TextStyle(
      fontFamily: 'Georgia',
      fontSize: size,
      fontWeight: FontWeight.bold,
      color: white,
      height: 1.04,
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's movement",
          style: TextStyle(
            color: Color(0xFF36B9FF),
            fontSize: 22,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text('Fitness Dashboard', style: _headingStyle(32)),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildHeaderAction({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF0C61B9),
              ),
              child: Icon(icon, color: white, size: 30),
            ),
            const SizedBox(height: 7),
            Text(label, style: _smallActionLabelStyle),
          ],
        ),
      ),
    );
  }

  Widget _buildPlannedWorkout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Planned Workout',
          textAlign: TextAlign.center,
          style: _headingStyle(29),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 300),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  children: [
                    _buildStartWorkoutButton(),
                    const SizedBox(height: 16),
                    _buildWorkoutActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStartWorkoutButton() {
    return Expanded(
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F9FD),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.black54),
        ),
        child: const Text(
          'Start Workout!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildHeaderAction(
          label: 'Exercises',
          icon: Icons.fitness_center,
          onTap: _showExerciseLibraryMessage,
        ),
        _buildHeaderAction(
          label: 'Goals',
          icon: Icons.flag_rounded,
          onTap: _openGoals,
        ),
      ],
    );
  }

  void _showExerciseLibraryMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connect this button to your exercise library.'),
      ),
    );
  }

  Widget _buildConsistency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Consistency', 30),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lightBlue,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Container(
            height: 104,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: paleBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: CustomPaint(
              painter: ConsistencyChartPainter(
                values: _consistencyData,
                lineColor: Colors.black,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalBests() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 22),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Personal Bests', 29, color: navy),
          const SizedBox(height: 18),
          Row(
            children: List.generate(4, (index) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index == 3 ? 0 : 6,
                    left: index == 0 ? 0 : 2,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Workout ${index + 1}',
                        textAlign: TextAlign.center,
                        style: _personalBestLabelStyle,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 46),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: paleBlue,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Text(
                          _personalBests[index],
                          style: _personalBestValueStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, double size, {Color color = white}) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: 'Georgia',
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: color,
        height: 1.04,
      ),
    );
  }

  Widget _buildBottomNavigation() {
    const labels = ['Fitness', 'Nutrition', 'Health', 'Settings'];

    const icons = [
      Icons.fitness_center,
      Icons.restaurant,
      Icons.favorite_outline,
      Icons.settings_outlined,
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF052858),
        border: Border(top: BorderSide(color: Color(0xFF104783), width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        10,
        12,
        10,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: List.generate(4, (index) {
          final selected = _selectedTab == index;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => _selectTab(index),
                borderRadius: BorderRadius.circular(28),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  constraints: const BoxConstraints(minHeight: 58),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selected ? blue : lightBlue,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lightBlue,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icons[index], size: 16, color: navy),
                          const SizedBox(width: 4),
                          Text(
                            labels[index],
                            style: const TextStyle(
                              color: navy,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class ConsistencyChartPainter extends CustomPainter {
  ConsistencyChartPainter({required this.values, required this.lineColor});

  final List<double> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final path = Path();

    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final normalized = range == 0 ? 0.5 : (values[i] - minValue) / range;
      final y = size.height * (0.9 - normalized * 0.8);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ConsistencyChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.lineColor != lineColor;
  }
}
