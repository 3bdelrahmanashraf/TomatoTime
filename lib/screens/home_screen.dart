import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tomato_time/providers/app_state.dart';
import 'package:tomato_time/screens/timer_tab.dart';
import 'package:tomato_time/screens/tasks_tab.dart';
import 'package:tomato_time/screens/stats_tab.dart';
import 'package:tomato_time/screens/settings_dialog.dart';
import 'package:tomato_time/screens/history_tab.dart';
import 'package:tomato_time/screens/sounds_tab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, appState, isDark),
            Expanded(
              child: IndexedStack(
                index: appState.currentTab.index,
                children: const [
                  TimerTab(),
                  TasksTab(),
                  StatsTab(),
                  HistoryTab(),
                  SoundsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: appState.currentTab.index,
        onTap: (index) => appState.setTab(AppTab.values[index]),
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
        selectedItemColor: isDark ? Colors.white : const Color(0xFF111827),
        unselectedItemColor: isDark ? Colors.white38 : Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.play_arrow_rounded), label: 'Timer'),
          BottomNavigationBarItem(icon: Icon(Icons.format_list_bulleted_rounded), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.music_note_rounded), label: 'Sounds'),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState appState, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'TomatoTime',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Welcome ${FirebaseAuth.instance.currentUser?.displayName ?? 'User'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              _HeaderIconButton(
                icon: Icons.logout,
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _HeaderIconButton(
                icon: appState.isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                onPressed: appState.toggleDarkMode,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _HeaderIconButton(
                icon: Icons.settings_outlined,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const SettingsDialog(),
                  );
                },
                isDark: isDark,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context, AppState appState, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          _TabButton(
            title: 'Timer',
            icon: null,
            isSelected: appState.currentTab == AppTab.timer,
            onTap: () => appState.setTab(AppTab.timer),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _TabButton(
            title: 'Tasks',
            icon: Icons.notes,
            isSelected: appState.currentTab == AppTab.tasks,
            onTap: () => appState.setTab(AppTab.tasks),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _TabButton(
            title: 'Stats',
            icon: Icons.bar_chart,
            isSelected: appState.currentTab == AppTab.stats,
            onTap: () => appState.setTab(AppTab.stats),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _TabButton(
            title: 'History',
            icon: Icons.history,
            isSelected: appState.currentTab == AppTab.history,
            onTap: () => appState.setTab(AppTab.history),
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _TabButton(
            title: 'Sounds',
            icon: Icons.music_note,
            isSelected: appState.currentTab == AppTab.sounds,
            onTap: () => appState.setTab(AppTab.sounds),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isDark;

  const _HeaderIconButton({required this.icon, required this.onPressed, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300),
      ),
      child: IconButton(
        icon: Icon(icon, color: isDark ? Colors.white70 : Colors.black54),
        onPressed: onPressed,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _TabButton({
    required this.title,
    this.icon,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected 
        ? (isDark ? Colors.white : const Color(0xFF111827))
        : (isDark ? const Color(0xFF1F2937) : Colors.white);
    
    final textColor = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : (isDark ? Colors.white70 : const Color(0xFF6B7280));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: 6),
            ],
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
