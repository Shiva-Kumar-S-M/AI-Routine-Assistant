import 'package:flutter/material.dart';
import '../../data/repositories/progress_repository.dart';
import '../../domain/models/weekly_recap.dart';
import '../widgets/chunky_button.dart';

class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  final ProgressRepository _repo = ProgressRepository();
  WeeklyRecap? _recap;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecap();
  }

  Future<void> _loadRecap() async {
    final recap = await _repo.getWeeklyRecap();
    if (mounted) {
      setState(() {
        _recap = recap;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E18),
      appBar: AppBar(
        title: const Text(
          'Weekly Recap',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 22,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: const Color(0xFF0E0E18),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C4DFF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Banner
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF651FFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'YOUR 7-DAY TRIUMPH',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Colors.white70,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.bolt_rounded, color: Color(0xFFFFD700), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '100% OFFLINE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${_recap!.winsCount} Focus Wins',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'You resisted impulse opens and completed dedicated focus intervals.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2x2 Metric Cards
                  Row(
                    children: [
                      Expanded(
                        child: _metricCard(
                          title: 'Time Reclaimed',
                          value: _recap!.formattedTimeReclaimed,
                          icon: Icons.hourglass_top_rounded,
                          color: const Color(0xFF00E676),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _metricCard(
                          title: 'XP Earned',
                          value: '+${_recap!.xpGained} XP',
                          icon: Icons.star_rounded,
                          color: const Color(0xFFFF9100),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _metricCard(
                          title: 'Best Focus Day',
                          value: _recap!.bestDayName,
                          icon: Icons.calendar_today_rounded,
                          color: const Color(0xFF00E5FF),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _metricCard(
                          title: 'Intervention Wins',
                          value: '${_recap!.winsCount} turns',
                          icon: Icons.shield_rounded,
                          color: const Color(0xFF7C4DFF),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // Algorithmic Smart Tip Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181827),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF2B2B44)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.lightbulb_rounded, color: Color(0xFFFFB300), size: 24),
                            SizedBox(width: 8),
                            Text(
                              'AI ROUTINE ADVICE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Color(0xFF8E8EA2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _recap!.smartTip,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  ChunkyButton(
                    text: 'Keep Crushing It',
                    icon: Icons.check_circle_rounded,
                    height: 54,
                    borderRadius: 18,
                    color: const Color(0xFF7C4DFF),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF181827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2B2B44)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E8EA2),
            ),
          ),
        ],
      ),
    );
  }
}
