import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TimerMode { work, shortBreak, longBreak }

enum AppTab { timer, tasks, stats, history, sounds }

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _userId;
  String? _selectedTaskId;

  static const Map<String, String> _soundUrls = {
    'Lo-Fi Beats':
        'https://cdn.pixabay.com/audio/2022/05/27/audio_1808fbf07a.mp3',
    'Rain': 'https://cdn.pixabay.com/audio/2025/03/24/audio_8b6ffc7087.mp3',
    'White Noise':
        'https://cdn.pixabay.com/audio/2025/06/28/audio_08a82f21bf.mp3',
  };

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    _initAudio();
    _loadLocalSettings();
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        _userId = user.uid;
        _hasGenerated = false; // Allow generating mock data per user if needed
        _loadDataFromCloud();
      } else {
        _userId = null;
        _tasks.clear();
        _history.clear();
        _xp = 0;
        _completedWorkSessions = 0;
        _stopTimer();
        _audioPlayer.stop();
        _isPlayingSound = false;
        notifyListeners();
      }
    });
  }

  AppTab _currentTab = AppTab.timer;
  AppTab get currentTab => _currentTab;

  void setTab(AppTab tab) {
    _currentTab = tab;
    notifyListeners();
  }

  String? get selectedTaskId => _selectedTaskId;
  TodoTask? get selectedTask => _selectedTaskId == null ? null : _tasks.firstWhere((t) => t.id == _selectedTaskId, orElse: () => _tasks.first);

  void setSelectedTask(String? id) {
    _selectedTaskId = id;
    notifyListeners();
  }

  TimerMode _currentMode = TimerMode.work;
  TimerMode get currentMode => _currentMode;

  bool _isDeepWorkMode = false;
  bool get isDeepWorkMode => _isDeepWorkMode;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // Settings
  double _workDuration = 25.0;
  double _shortBreakDuration = 5.0;
  double _longBreakDuration = 15.0;
  int _sessionsUntilLongBreak = 4;

  double get workDuration => _workDuration;
  double get shortBreakDuration => _shortBreakDuration;
  double get longBreakDuration => _longBreakDuration;
  int get sessionsUntilLongBreak => _sessionsUntilLongBreak;

  // Timer state
  Timer? _timer;
  int _totalSeconds = 25 * 60;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;

  // Progress state
  int _xp = 0;
  int _completedWorkSessions = 0;

  int get totalSeconds => _totalSeconds;
  int get remainingSeconds => _remainingSeconds;
  bool get isRunning => _isRunning;
  int get xp => _xp;
  int get completedWorkSessions => _completedWorkSessions;

  // Leveling system
  int get currentLevel {
    int lvl = 1;
    int xpRemaining = _xp;
    while (xpRemaining >= xpRequiredForLevel(lvl)) {
      xpRemaining -= xpRequiredForLevel(lvl);
      lvl++;
    }
    return lvl;
  }

  int get xpInCurrentLevel {
    int lvl = 1;
    int xpRemaining = _xp;
    while (xpRemaining >= xpRequiredForLevel(lvl)) {
      xpRemaining -= xpRequiredForLevel(lvl);
      lvl++;
    }
    return xpRemaining;
  }

  int xpRequiredForLevel(int level) {
    // Base 100 XP, increases by 50 for each level
    return 100 + (level - 1) * 50;
  }

  double get levelProgress {
    int required = xpRequiredForLevel(currentLevel);
    return xpInCurrentLevel / required;
  }

  int get xpToNextLevel {
    return xpRequiredForLevel(currentLevel) - xpInCurrentLevel;
  }

  bool _deepWorkBroke = false;
  bool get deepWorkBroke => _deepWorkBroke;

  void clearDeepWorkBroke() {
    _deepWorkBroke = false;
    notifyListeners();
  }

  double get progress => _totalSeconds > 0
      ? (_totalSeconds - _remainingSeconds) / _totalSeconds
      : 0.0;

  void updateSettings({
    double? work,
    double? shortBreak,
    double? longBreak,
    int? sessions,
  }) {
    if (work != null) _workDuration = work;
    if (shortBreak != null) _shortBreakDuration = shortBreak;
    if (longBreak != null) _longBreakDuration = longBreak;
    if (sessions != null) _sessionsUntilLongBreak = sessions;

    _saveLocalSettings();
    // Refresh current timer if not running (or reset it)
    if (!_isRunning) {
      setMode(_currentMode);
    }
    _syncProfileToCloud();
    notifyListeners();
  }

  void setMode(TimerMode mode) {
    _currentMode = mode;
    _stopTimer();

    switch (mode) {
      case TimerMode.work:
        _totalSeconds = (_workDuration * 60).toInt();
        break;
      case TimerMode.shortBreak:
        _totalSeconds = (_shortBreakDuration * 60).toInt();
        break;
      case TimerMode.longBreak:
        _totalSeconds = (_longBreakDuration * 60).toInt();
        break;
    }
    _remainingSeconds = _totalSeconds;
    notifyListeners();
  }

  void toggleTimer() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    if (_remainingSeconds > 0) {
      _isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          notifyListeners();
        } else {
          _stopTimer();
          // Timer finished
          _recordSessionFinished();
          _remainingSeconds = _totalSeconds;
          notifyListeners();
        }
      });
      notifyListeners();
    }
  }

  void _pauseTimer() {
    _isRunning = false;
    _timer?.cancel();
    notifyListeners();
  }

  void _stopTimer() {
    _isRunning = false;
    _timer?.cancel();
  }

  void resetTimer() {
    _stopTimer();
    _remainingSeconds = _totalSeconds;
    notifyListeners();
  }

  void toggleDeepWorkMode() {
    _isDeepWorkMode = !_isDeepWorkMode;
    _saveLocalSettings();
    _syncProfileToCloud();
    notifyListeners();
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    _saveLocalSettings();
    _syncProfileToCloud();
    notifyListeners();
  }

  // Tasks state
  List<TodoTask> _tasks = [];
  List<TodoTask> get tasks => _tasks;

  static bool _hasGenerated = false;

  Future<void> _loadDataFromCloud() async {
    if (_userId == null) return;
    try {
      // Load user profile
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _xp = data['xp'] ?? 0;
        _completedWorkSessions = data['completedWorkSessions'] ?? 0;
        _workDuration = data['workDuration'] ?? 25.0;
        _shortBreakDuration = data['shortBreakDuration'] ?? 5.0;
        _longBreakDuration = data['longBreakDuration'] ?? 15.0;
        _sessionsUntilLongBreak = data['sessionsUntilLongBreak'] ?? 4;
        _isDarkMode = data['isDarkMode'] ?? false;
        _isDeepWorkMode = data['isDeepWorkMode'] ?? false;
        _selectedSound = data['selectedSound'] ?? 'Lo-Fi Beats';
        _soundVolume = data['soundVolume'] ?? 0.5;

        _saveLocalSettings();
        if (!_isRunning) {
          setMode(_currentMode); // Update timer based on loaded settings
        }
      }

      // Load tasks
      final tasksSnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('tasks')
          .get();
      _tasks = tasksSnapshot.docs
          .map((doc) => TodoTask.fromMap(doc.data(), doc.id))
          .toList();

      // Load history
      final historySnapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('history')
          .orderBy('date', descending: false)
          .get();
      _history = historySnapshot.docs
          .map((doc) => SessionRecord.fromMap(doc.data()))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Future<void> _syncProfileToCloud() async {
    if (_userId == null) return;
    try {
      await _firestore.collection('users').doc(_userId).set({
        'xp': _xp,
        'completedWorkSessions': _completedWorkSessions,
        'workDuration': _workDuration,
        'shortBreakDuration': _shortBreakDuration,
        'longBreakDuration': _longBreakDuration,
        'sessionsUntilLongBreak': _sessionsUntilLongBreak,
        'isDarkMode': _isDarkMode,
        'isDeepWorkMode': _isDeepWorkMode,
        'selectedSound': _selectedSound,
        'soundVolume': _soundVolume,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error syncing profile: $e");
    }
  }

  Future<void> generateMockData() async {
    if (_userId == null) return;
    // Clear old data
    final oldTasks = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .get();
    for (var doc in oldTasks.docs) {
      await doc.reference.delete();
    }
    final oldHistory = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('history')
        .get();
    for (var doc in oldHistory.docs) {
      await doc.reference.delete();
    }

    final now = DateTime.now();
    int seed = now.millisecond;

    // Generate exactly 6 sample tasks with random tomato counts
    final List<String> taskNames = [
      'Implement API endpoints',
      'Refactor Provider to Riverpod',
      'Write Unit Tests',
      'Design Landing Page',
      'Fix Memory Leaks',
      'Configure Firebase Analytics',
    ];

    for (var name in taskNames) {
      seed = (seed * 9301 + 49297) % 233280;
      int tCount = seed % 6; // 0 to 5 tomatoes
      bool isCompleted = tCount > 0 && (seed % 2 == 0); // randomly complete
      await _firestore.collection('users').doc(_userId).collection('tasks').add(
        {'title': name, 'isCompleted': isCompleted, 'tomatoCount': tCount},
      );
    }

    // Generate history for the last 7 days exactly
    int generatedXp = 0;
    int generatedSessions = 0;

    for (int i = 0; i < 7; i++) {
      final date = now.subtract(Duration(days: i));

      // Randomly generate between 3 to 6 work sessions per day
      seed = (seed * 9301 + 49297) % 233280;
      int sessionsToday = 3 + (seed % 4);

      for (int j = 0; j < sessionsToday; j++) {
        // Space them out by a few hours
        final recordDate = date.subtract(Duration(hours: j * 2));

        final int workMinutes = 25;

        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('history')
            .add({
              'date': recordDate.toIso8601String(),
              'mode': TimerMode.work.index,
              'durationMinutes': workMinutes,
            });

        // Add random breaks
        if (seed % 2 == 0) {
          seed = (seed * 9301 + 49297) % 233280;
          int breakMinutes = [5, 15][seed % 2];
          TimerMode breakMode = breakMinutes == 15
              ? TimerMode.longBreak
              : TimerMode.shortBreak;

          await _firestore
              .collection('users')
              .doc(_userId)
              .collection('history')
              .add({
                'date': recordDate
                    .add(Duration(minutes: workMinutes))
                    .toIso8601String(),
                'mode': breakMode.index,
                'durationMinutes': breakMinutes,
              });
        }

        generatedXp += 10;
        generatedSessions++;
      }
    }

    _xp = generatedXp;
    _completedWorkSessions = generatedSessions;
    await _syncProfileToCloud();

    // Reload everything to update UI
    await _loadDataFromCloud();
  }

  Future<void> addTask(String title) async {
    if (_userId == null) return;
    if (title.trim().isNotEmpty) {
      final newTask = TodoTask(id: '', title: title.trim());

      try {
        // Add to Firestore
        final docRef = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('tasks')
            .add(newTask.toMap());

        // Update local state with the new cloud ID
        _tasks.add(
          TodoTask(
            id: docRef.id,
            title: newTask.title,
            isCompleted: newTask.isCompleted,
            tomatoCount: newTask.tomatoCount,
          ),
        );
        notifyListeners();
      } catch (e) {
        debugPrint("Error adding task: $e");
      }
    }
  }

  Future<void> toggleTask(String id) async {
    if (_userId == null) return;
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index != -1) {
      final newStatus = !_tasks[index].isCompleted;
      _tasks[index].isCompleted = newStatus;
      notifyListeners();

      try {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('tasks')
            .doc(id)
            .update({'isCompleted': newStatus});
      } catch (e) {
        debugPrint("Error updating task: $e");
      }
    }
  }

  Future<void> deleteTask(String id) async {
    if (_userId == null) return;
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('tasks')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint("Error deleting task: $e");
    }
  }

  // History state
  List<SessionRecord> _history = [];
  List<SessionRecord> get history => _history;

  // Sound state
  String _selectedSound = 'Lo-Fi Beats';
  double _soundVolume = 0.5;
  bool _isPlayingSound = false;

  String get selectedSound => _selectedSound;
  double get soundVolume => _soundVolume;
  bool get isPlayingSound => _isPlayingSound;

  void setSound(String sound) {
    if (_selectedSound != sound) {
      _selectedSound = sound;
      if (_isPlayingSound) {
        _isPlayingSound = false;
        _audioPlayer.stop();
      }
      _saveLocalSettings();
      _syncProfileToCloud();
      notifyListeners();
    }
  }

  void setSoundVolume(double volume) {
    _soundVolume = volume;
    _audioPlayer.setVolume(volume);
    _saveLocalSettings();
    _syncProfileToCloud();
    notifyListeners();
  }

  void toggleSoundPlay() {
    _isPlayingSound = !_isPlayingSound;
    if (_isPlayingSound) {
      _startPlayback();
    } else {
      _audioPlayer.stop();
    }
    notifyListeners();
  }

  Future<void> _initAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setVolume(_soundVolume);
    } catch (e) {
      debugPrint("Error initializing audio: $e");
    }
  }

  Future<void> _startPlayback() async {
    final url = _soundUrls[_selectedSound];
    if (url != null) {
      try {
        await _audioPlayer.setUrl(url);
        await _audioPlayer.setVolume(_soundVolume);
        await _audioPlayer.seek(Duration.zero); // Start from beginning
        _audioPlayer.play();
      } catch (e) {
        debugPrint("Error playing sound: $e");
        _isPlayingSound = false;
        notifyListeners();
      }
    }
  }

  Future<void> _recordSessionFinished() async {
    if (_userId == null) return;

    // Vibrate on session completion
    HapticFeedback.vibrate();

    final record = SessionRecord(
      date: DateTime.now(),
      mode: _currentMode,
      durationMinutes: _totalSeconds ~/ 60,
    );
    _history.add(record);

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('history')
          .add(record.toMap());
    } catch (e) {
      debugPrint("Error adding history: $e");
    }

    if (_currentMode == TimerMode.work) {
      _xp += _isDeepWorkMode ? 20 : 10; // Double XP for Deep Work
      _completedWorkSessions++;

      // Increment tomato count for the selected task if one exists
      if (_selectedTaskId != null) {
        try {
          final taskIndex = _tasks.indexWhere((t) => t.id == _selectedTaskId);
          if (taskIndex != -1) {
            _tasks[taskIndex].tomatoCount++;
            await _firestore
                .collection('users')
                .doc(_userId)
                .collection('tasks')
                .doc(_selectedTaskId)
                .update({'tomatoCount': _tasks[taskIndex].tomatoCount});
          }
        } catch (e) {
          debugPrint("Error updating tomatoCount: $e");
        }
      }

      // Transition to break
      if (_completedWorkSessions % _sessionsUntilLongBreak == 0) {
        setMode(TimerMode.longBreak);
      } else {
        setMode(TimerMode.shortBreak);
      }
    } else {
      // After a break, go back to work
      setMode(TimerMode.work);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isDeepWorkMode &&
        _isRunning &&
        (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive)) {
      _breakDeepWork();
    }
  }

  void _breakDeepWork() {
    _stopTimer();
    _remainingSeconds = _totalSeconds;
    _xp = (_xp - 10).clamp(0, 1000000).toInt(); // Penalty
    _deepWorkBroke = true;
    _syncProfileToCloud();
    notifyListeners();

    // Haptic feedback if on device
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _workDuration = prefs.getDouble('workDuration') ?? 25.0;
      _shortBreakDuration = prefs.getDouble('shortBreakDuration') ?? 5.0;
      _longBreakDuration = prefs.getDouble('longBreakDuration') ?? 15.0;
      _sessionsUntilLongBreak = prefs.getInt('sessionsUntilLongBreak') ?? 4;
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
      _isDeepWorkMode = prefs.getBool('isDeepWorkMode') ?? false;
      _selectedSound = prefs.getString('selectedSound') ?? 'Lo-Fi Beats';
      _soundVolume = prefs.getDouble('soundVolume') ?? 0.5;

      if (!_isRunning) {
        setMode(_currentMode);
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading local settings: $e");
    }
  }

  Future<void> _saveLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('workDuration', _workDuration);
      await prefs.setDouble('shortBreakDuration', _shortBreakDuration);
      await prefs.setDouble('longBreakDuration', _longBreakDuration);
      await prefs.setInt('sessionsUntilLongBreak', _sessionsUntilLongBreak);
      await prefs.setBool('isDarkMode', _isDarkMode);
      await prefs.setBool('isDeepWorkMode', _isDeepWorkMode);
      await prefs.setString('selectedSound', _selectedSound);
      await prefs.setDouble('soundVolume', _soundVolume);
    } catch (e) {
      debugPrint("Error saving local settings: $e");
    }
  }
}

class TodoTask {
  final String id;
  final String title;
  bool isCompleted;
  int tomatoCount;

  TodoTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.tomatoCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isCompleted': isCompleted,
      'tomatoCount': tomatoCount,
    };
  }

  factory TodoTask.fromMap(Map<String, dynamic> map, String documentId) {
    return TodoTask(
      id: documentId,
      title: map['title'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
      tomatoCount: map['tomatoCount'] ?? 0,
    );
  }
}

class SessionRecord {
  final DateTime date;
  final TimerMode mode;
  final int durationMinutes;

  SessionRecord({
    required this.date,
    required this.mode,
    required this.durationMinutes,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date.toIso8601String(),
      'mode': mode.index,
      'durationMinutes': durationMinutes,
    };
  }

  factory SessionRecord.fromMap(Map<String, dynamic> map) {
    return SessionRecord(
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      mode: TimerMode.values[map['mode'] ?? 0],
      durationMinutes: map['durationMinutes'] ?? 0,
    );
  }
}
