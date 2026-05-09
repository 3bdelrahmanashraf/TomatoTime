import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomato_time/providers/app_state.dart';

class StatsTab extends StatelessWidget {
  const StatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;

    final workSessions = appState.history
        .where((s) => s.mode == TimerMode.work)
        .toList();
    final totalSessions = workSessions.length;
    final focusHours = workSessions.fold<double>(
      0,
      (sum, s) => sum + (s.durationMinutes / 60),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 32),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Sessions',
                      '$totalSessions',
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Focus Hours',
                      '${focusHours.toStringAsFixed(1)}h',
                      isDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Last 7 Days',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF334155),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 24),
            _buildChart(workSessions, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF374151).withOpacity(0.4)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value.replaceAll('h', ''),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -1,
                  ),
                ),
                if (value.contains('h'))
                  TextSpan(
                    text: ' h',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<SessionRecord> workSessions, bool isDark) {
    final textColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);
    final barColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B);
    final gridLineColor = isDark
        ? Colors.white10
        : Colors.black.withOpacity(0.05);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<String> dayLabels = [];
    final List<double> dailyHours = [];

    const daysCount = 7;
    for (int i = daysCount - 1; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      dayLabels.add(_getShortWeekday(date.weekday));

      final daySessions = workSessions.where((s) {
        final sDate = DateTime(s.date.year, s.date.month, s.date.day);
        return sDate.isAtSameMomentAs(date);
      });

      final hours = daySessions.fold<double>(
        0,
        (sum, s) => sum + (s.durationMinutes / 60),
      );
      dailyHours.add(hours);
    }

    final double maxVal = dailyHours.isEmpty
        ? 0
        : dailyHours.reduce((a, b) => a > b ? a : b);
    final double yMax = maxVal > 0 ? (maxVal * 1.2).ceilToDouble() : 4.0;

    return SizedBox(
      height: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Y-axis labels
          SizedBox(
            width: 35,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _yLabel(yMax),
                _yLabel(yMax * 0.75),
                _yLabel(yMax * 0.5),
                _yLabel(yMax * 0.25),
                _yLabel(0),
                const SizedBox(height: 28), // align with bottom axis
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Chart area
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // Horizontal dotted lines
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          return CustomPaint(
                            size: const Size(double.infinity, 1),
                            painter: DottedLinePainter(color: gridLineColor),
                          );
                        }),
                      ),
                      // Bars
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: List.generate(daysCount, (index) {
                            final fraction = yMax > 0
                                ? (dailyHours[index] / yMax)
                                : 0.0;
                            return Flexible(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                ),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 32,
                                      ),
                                      height: constraints.maxHeight * fraction,
                                      decoration: BoxDecoration(
                                        color: barColor,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(6),
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // X-axis labels
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: dayLabels.map((label) {
                      return Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _yLabel(double value) {
    String text = value == 0
        ? '0'
        : value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    if (text.endsWith('.00')) text = text.substring(0, text.length - 3);

    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _getShortWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}

class DottedLinePainter extends CustomPainter {
  final Color color;
  DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double dashWidth = 3;
    const double dashSpace = 3;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
