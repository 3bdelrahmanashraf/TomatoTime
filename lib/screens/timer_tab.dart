import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tomato_time/providers/app_state.dart';

class TimerTab extends StatelessWidget {
  const TimerTab({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;

    if (appState.deepWorkBroke) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showDeepWorkInterruptionDialog(context, appState);
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          _buildTaskSelector(context, appState, isDark),
          const SizedBox(height: 24),
          _buildModeSelector(context, appState, isDark),
          const SizedBox(height: 40),
          _buildTimerCircle(context, appState),
          const SizedBox(height: 30),
          _buildPlayButton(appState),
          const SizedBox(height: 16),
          Text(
            "Session #${appState.completedWorkSessions + 1}",
            style: TextStyle(
              color: isDark ? Colors.white54 : const Color(0xFF9CA3AF),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 30),
          _buildDeepWorkCard(context, appState, isDark),
          const SizedBox(height: 16),
          _buildProgressCard(context, isDark),
        ],
      ),
    );
  }

  Widget _buildModeSelector(BuildContext context, AppState appState, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModeButton(
          title: 'Work',
          isSelected: appState.currentMode == TimerMode.work,
          onTap: () => appState.setMode(TimerMode.work),
          selectedColor: const Color(0xFF4A1A1A),
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _ModeButton(
          title: 'Short Break',
          isSelected: appState.currentMode == TimerMode.shortBreak,
          onTap: () => appState.setMode(TimerMode.shortBreak),
          selectedColor: const Color(0xFF144520),
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _ModeButton(
          title: 'Long Break',
          isSelected: appState.currentMode == TimerMode.longBreak,
          onTap: () => appState.setMode(TimerMode.longBreak),
          selectedColor: const Color(0xFF1A365D),
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildTimerCircle(BuildContext context, AppState appState) {
    Color ringColor;
    Color textColor;
    Color progressColor;

    switch (appState.currentMode) {
      case TimerMode.work:
        ringColor = const Color(0xFF4A1B1B).withOpacity(0.3);
        progressColor = const Color(0xFF4A1B1B);
        textColor = const Color(0xFFFA5252);
        break;
      case TimerMode.shortBreak:
        ringColor = const Color(0xFF173B1B).withOpacity(0.3);
        progressColor = const Color(0xFF173B1B);
        textColor = const Color(0xFF69D788);
        break;
      case TimerMode.longBreak:
        ringColor = const Color(0xFF112F48).withOpacity(0.3);
        progressColor = const Color(0xFF112F48);
        textColor = const Color(0xFF8AB4F8);
        break;
    }

    final minutes = (appState.remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (appState.remainingSeconds % 60).toString().padLeft(2, '0');
    final timeString = "$minutes\n$seconds";

    return SizedBox(
      width: 250,
      height: 250,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: 6,
            color: ringColor,
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: appState.progress),
            duration: appState.progress == 0 ? Duration.zero : const Duration(seconds: 1),
            curve: Curves.linear,
            builder: (context, value, child) {
              return CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                color: progressColor,
                backgroundColor: Colors.transparent,
              );
            },
          ),
          Center(
            child: Text(
              timeString,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 70,
                fontWeight: FontWeight.w300,
                color: textColor,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(AppState appState) {
    Color buttonColor;
    switch (appState.currentMode) {
      case TimerMode.work:
        buttonColor = const Color(0xFFFA5252);
        break;
      case TimerMode.shortBreak:
        buttonColor = const Color(0xFF69D788);
        break;
      case TimerMode.longBreak:
        buttonColor = const Color(0xFF8AB4F8);
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: appState.toggleTimer,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: buttonColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              appState.isRunning ? Icons.pause : Icons.play_arrow,
              color: const Color(0xFF111827),
              size: 32,
            ),
          ),
        ),
        if (appState.progress > 0) ...[
          const SizedBox(width: 16),
          GestureDetector(
            onTap: appState.resetTimer,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.withOpacity(0.5), width: 2),
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.grey,
                size: 24,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDeepWorkCard(BuildContext context, AppState appState, bool isDark) {
    final bool isEnabled = appState.isDeepWorkMode;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isEnabled 
            ? (isDark ? const Color(0xFF451A1A) : const Color(0xFFFCE8E8))
            : (isDark ? const Color(0xFF1F2937) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: isEnabled 
            ? Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, 
                      color: isEnabled 
                          ? const Color(0xFFDC2626)
                          : (isDark ? Colors.white : Colors.black87), 
                      size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Deep Work Mode',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isEnabled 
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: appState.toggleDeepWorkMode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEnabled 
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: isEnabled ? const BorderSide(color: Colors.white, width: 1.5) : BorderSide.none,
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: const Size(0, 36),
                ),
                child: Text(
                  isEnabled ? 'Disable' : 'Enable',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isEnabled) ...[
            _buildDeepWorkFeatureCard(
              icon: Icons.notifications_off_outlined,
              title: 'Notifications Blocked',
              subtitle: 'Stay focused without distractions',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _buildDeepWorkFeatureCard(
              icon: Icons.smartphone_outlined,
              title: 'Stay on App',
              subtitle: "You'll be reminded if you switch away",
              isDark: isDark,
            ),
          ] else ...[
            Text(
              'Enable Deep Work Mode to minimize distractions and maximize focus during your work sessions.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeepWorkFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFDC2626), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, bool isDark) {
    final appState = context.watch<AppState>();
    final int level = appState.currentLevel;
    final double progressValue = appState.levelProgress;
    final int xpToNext = appState.xpToNextLevel;

    // Calculate Streak
    final Set<String> activeDays = {};
    for (var session in appState.history) {
      if (session.mode == TimerMode.work) {
        activeDays.add('${session.date.year}-${session.date.month}-${session.date.day}');
      }
    }
    final int streakDays = activeDays.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level $level',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    level < 5 ? 'Getting Started' : 'Productivity Master',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${appState.xp} XP',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$xpToNext to next level',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressValue == 0.0 ? 0.001 : progressValue,
              backgroundColor: isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(isDark ? const Color(0xFF3B82F6) : const Color(0xFF1E293B)),
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Badges',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadgeItem(Icons.star_border, 'First Session', appState.completedWorkSessions >= 1, isDark),
              const SizedBox(width: 12),
              _buildBadgeItem(Icons.bolt, '3 Day Streak', streakDays >= 3, isDark),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadgeItem(Icons.emoji_events_outlined, '7 Day Streak', streakDays >= 7, isDark),
              const SizedBox(width: 12),
              _buildBadgeItem(Icons.military_tech_outlined, '100 Sessions', appState.completedWorkSessions >= 100, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem(IconData icon, String label, bool isActive, bool isDark) {
    // ... (rest of badge code)
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isActive 
              ? (isDark ? const Color(0xFF422006) : const Color(0xFFFEF3C7))
              : (isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? (isDark ? const Color(0xFFCA8A04) : const Color(0xFFFDE047))
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isActive ? (isDark ? const Color(0xFFFACC15) : const Color(0xFFEAB308)) : (isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  color: isActive ? (isDark ? Colors.white : const Color(0xFF0F172A)) : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskSelector(BuildContext context, AppState appState, bool isDark) {
    final selectedTask = appState.selectedTask;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CURRENT TASK',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blueAccent : const Color(0xFF64748B).withOpacity(0.8),
                  letterSpacing: 0.8,
                ),
              ),
              if (selectedTask != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${selectedTask.tomatoCount} ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      const Text('🍅', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _showTaskSelectionDialog(context, appState),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Icon(
                  Icons.play_arrow_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 26,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedTask?.title ?? 'Select a task to start',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showTaskSelectionDialog(BuildContext context, AppState appState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: appState.isDarkMode ? const Color(0xFF111827) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final tasks = appState.tasks.where((t) => !t.isCompleted).toList();
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Task',
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  color: appState.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 20),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No active tasks. Create one in Tasks tab!',
                      style: TextStyle(color: appState.isDarkMode ? Colors.white60 : Colors.black54),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final isSelected = task.id == appState.selectedTaskId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: appState.isDarkMode ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${task.tomatoCount} 🍅', style: const TextStyle(fontSize: 14)),
                            if (isSelected) ...[
                              const SizedBox(width: 12),
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            ],
                          ],
                        ),
                        onTap: () {
                          appState.setSelectedTask(task.id);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
  void _showDeepWorkInterruptionDialog(BuildContext context, AppState appState) {
    appState.clearDeepWorkBroke();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: appState.isDarkMode ? const Color(0xFF1F2937) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 10),
            Text('Focus Lost!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Deep Work mode was interrupted because you left the app. \n\n'
          '• Timer Reset\n'
          '• -10 XP Penalty applied',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I Understand', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final bool isDark;

  const _ModeButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : (isDark ? const Color(0xFF1F2937) : Colors.white),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
