import 'package:flutter/material.dart';

import 'sleep_screens.dart';

const _healthNavy = Color(0xFF062D63);
const _healthBlue = Color(0xFF086AC7);
const _healthPaleBlue = Color(0xFFE5F4FF);
const _healthLightBlue = Color(0xFFC2DFF2);

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _healthNavy,
      appBar: AppBar(title: const Text('Health'), backgroundColor: _healthNavy),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            const Text(
              'Small steps, stronger health.',
              style: TextStyle(
                color: Color(0xFF36B9FF),
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take care of your whole self',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Georgia',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 20),
            _QuoteCard(
              quote: '“The groundwork for all happiness is good health.”',
              author: '— James Leigh Hunt',
            ),
            const SizedBox(height: 24),
            _HealthActionCard(
              icon: Icons.menu_book_rounded,
              title: 'Health Resources',
              subtitle: 'Find practical information for your everyday care.',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HealthResourcesScreen(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _HealthActionCard(
              icon: Icons.health_and_safety_outlined,
              title: 'First-Aid Techniques',
              subtitle: 'Review essential steps for common emergencies.',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FirstAidScreen()),
              ),
            ),
            const SizedBox(height: 14),
            _HealthActionCard(
              icon: Icons.nightlight_round,
              title: 'Sleep Tracker',
              subtitle: 'Log your sleep time, quality, and notes.',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SleepTrackerScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.author});

  final String quote;
  final String author;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _healthPaleBlue,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded, color: _healthBlue, size: 30),
          const SizedBox(height: 8),
          Text(
            quote,
            style: const TextStyle(
              color: _healthNavy,
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(author, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _HealthActionCard extends StatelessWidget {
  const _HealthActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _healthPaleBlue,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: _healthBlue,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _healthNavy,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _healthBlue),
            ],
          ),
        ),
      ),
    );
  }
}

class HealthResourcesScreen extends StatelessWidget {
  const HealthResourcesScreen({super.key});

  static const _resources = [
    (
      'Healthcare plans',
      'Understand primary care, insurance, and choosing a provider.',
      Icons.medical_services_outlined,
    ),
    (
      'Dental care',
      'Learn about checkups, cleanings, prevention, and oral health.',
      Icons.sentiment_satisfied_alt_outlined,
    ),
    (
      'Vision care',
      'Review eye exams, preventive care, and common vision services.',
      Icons.visibility_outlined,
    ),
    (
      'Preventive screenings',
      'Keep track of age- and risk-appropriate health screenings.',
      Icons.fact_check_outlined,
    ),
    (
      'Mental wellbeing',
      'Explore ways to support your emotional health and find help.',
      Icons.psychology_outlined,
    ),
    (
      'Medication safety',
      'Helpful reminders for taking and storing medication safely.',
      Icons.medication_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) => _InformationListScreen(
    title: 'Health Resources',
    subtitle: 'Practical information to help you stay informed.',
    items: _resources,
  );
}

class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key});

  static const _techniques = [
    (
      'CPR',
      'Call emergency services, begin chest compressions, and use an AED if available. Follow dispatcher instructions.',
      Icons.favorite_border_rounded,
    ),
    (
      'Heimlich maneuver',
      'For a conscious choking adult or child, give back blows and abdominal thrusts. Call emergency services immediately.',
      Icons.air_rounded,
    ),
    (
      'Severe bleeding',
      'Apply firm, direct pressure with a clean dressing and seek emergency help if bleeding does not stop.',
      Icons.water_drop_outlined,
    ),
    (
      'Burns',
      'Cool a minor burn under clean, cool running water. Do not apply ice or break blisters.',
      Icons.local_fire_department_outlined,
    ),
    (
      'Sprains and strains',
      'Rest the area, use a cold pack wrapped in cloth, and elevate it when possible.',
      Icons.accessibility_new_rounded,
    ),
    (
      'Fainting',
      'Lay the person flat, check breathing, and call for help if they do not recover quickly.',
      Icons.airline_seat_flat_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) => _InformationListScreen(
    title: 'First-Aid Techniques',
    subtitle: 'For emergencies, call your local emergency number first.',
    items: _techniques,
    showDisclaimer: true,
  );
}

class _InformationListScreen extends StatelessWidget {
  const _InformationListScreen({
    required this.title,
    required this.subtitle,
    required this.items,
    this.showDisclaimer = false,
  });

  final String title;
  final String subtitle;
  final List<(String, String, IconData)> items;
  final bool showDisclaimer;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _healthNavy,
    appBar: AppBar(title: Text(title), backgroundColor: _healthNavy),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Text(
          subtitle,
          style: const TextStyle(color: _healthLightBlue, fontSize: 15),
        ),
        if (showDisclaimer) ...[
          const SizedBox(height: 12),
          const Text(
            'This information is educational and does not replace professional medical training or advice.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        for (final item in items) ...[
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: _healthPaleBlue,
                foregroundColor: _healthBlue,
                child: Icon(item.$3),
              ),
              title: Text(
                item.$1,
                style: const TextStyle(
                  color: _healthNavy,
                  fontWeight: FontWeight.bold,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [
                Text(
                  item.$2,
                  style: const TextStyle(color: Colors.black87, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  );
}
