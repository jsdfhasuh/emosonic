import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LogLevel { debug, info, warning, error }

class Logger {
  static Logger? _instance;
  File? _logFile;
  IOSink? _logSink;
  final String _name;
  bool _initialized = false;
  int _logCount = 0;
  
  // Log level - change this to control verbosity
  static LogLevel _minLogLevel = LogLevel.info; // Only log INFO and above by default
  static const String _logLevelKey = 'app_log_level';
  
  // Log rotation constants
  static const String _currentLogFile = 'debug.log';
  static const String _previousLogFile = 'debug.log.1';
  static const int _maxLogSize = 10 * 1024 * 1024; // 10MB max size
  static const int _sizeCheckInterval = 100; // Check size every 100 logs

  Logger._internal(this._name);

  factory Logger(String name) {
    _instance ??= Logger._internal(name);
    return _instance!;
  }
  
  // Load saved log level from local storage
  static Future<void> loadLogLevel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLevel = prefs.getString(_logLevelKey);
      if (savedLevel != null) {
        _minLogLevel = LogLevel.values.firstWhere(
          (e) => e.name == savedLevel,
          orElse: () => LogLevel.info,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to load log level: $e');
    }
  }
  
  // Set minimum log level and save to local storage
  static Future<void> setLogLevel(LogLevel level) async {
    _minLogLevel = level;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_logLevelKey, level.name);
    } catch (e) {
      // ignore: avoid_print
      print('Failed to save log level: $e');
    }
  }
  
  // Get current log level
  static LogLevel getLogLevel() => _minLogLevel;

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final directory = await getApplicationDocumentsDirectory();
      final currentLogPath = '${directory.path}/$_currentLogFile';
      final previousLogPath = '${directory.path}/$_previousLogFile';
      
      // Rotate logs: move current to previous if exists
      await _rotateLogs(currentLogPath, previousLogPath);
      
      _logFile = File(currentLogPath);
      
      // Create file if not exists
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
      
      _logSink = _logFile!.openWrite(mode: FileMode.append);
      _initialized = true;
      
      // Don't call info() here to avoid recursion
      _directLog('INFO', 'Logger initialized. Log file: $currentLogPath');
      _directLog('INFO', 'Previous log file: $previousLogPath');
      _directLog('INFO', 'Log level: ${_minLogLevel.name.toUpperCase()}');
    } catch (e) {
      // ignore: avoid_print
      print('Failed to initialize logger: $e');
    }
  }
  
  Future<void> _rotateLogs(String currentPath, String previousPath) async {
    try {
      final currentFile = File(currentPath);
      
      // If current log exists, move it to previous
      if (await currentFile.exists()) {
        // Delete old previous log if exists
        final previousFile = File(previousPath);
        if (await previousFile.exists()) {
          await previousFile.delete();
        }
        
        // Move current to previous
        await currentFile.rename(previousPath);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to rotate logs: $e');
    }
  }
  
  Future<void> _checkLogSize() async {
    if (_logFile == null) return;
    
    try {
      final size = await _logFile!.length();
      if (size > _maxLogSize) {
        // Close current sink
        await _logSink?.close();
        
        // Rotate logs
        final directory = await getApplicationDocumentsDirectory();
        final currentLogPath = '${directory.path}/$_currentLogFile';
        final previousLogPath = '${directory.path}/$_previousLogFile';
        await _rotateLogs(currentLogPath, previousLogPath);
        
        // Reopen log file
        _logFile = File(currentLogPath);
        await _logFile!.create(recursive: true);
        _logSink = _logFile!.openWrite(mode: FileMode.append);
        
        _directLog('INFO', 'Log file rotated due to size limit');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to check log size: $e');
    }
  }

  void _directLog(String level, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$level] [$_name] $message\n';
    
    // ignore: avoid_print
    print(logLine.trim());
    
    if (_initialized && _logSink != null) {
      _logSink!.write(logLine);
    }
  }

  bool _shouldLog(LogLevel level) {
    return level.index >= _minLogLevel.index;
  }

  void _log(LogLevel level, String message) {
    if (!_shouldLog(level)) return;
    
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [${level.name.toUpperCase()}] [$_name] $message\n';
    
    // Print to console
    // ignore: avoid_print
    print(logLine.trim());
    
    // Write to file
    if (_initialized && _logSink != null) {
      _logSink!.write(logLine);
      
      // Check size periodically
      _logCount++;
      if (_logCount % _sizeCheckInterval == 0) {
        _checkLogSize();
      }
    }
  }

  void debug(String message) {
    _log(LogLevel.debug, message);
  }

  void info(String message) {
    _log(LogLevel.info, message);
  }

  void warning(String message) {
    _log(LogLevel.warning, message);
  }

  void error(String message) {
    _log(LogLevel.error, message);
  }

  Future<void> close() async {
    if (_initialized && _logSink != null) {
      await _logSink!.close();
      _initialized = false;
    }
  }

  static Future<void> clearLogs() async {
    try {
      // Close current sink first to release file handle
      if (_instance != null && _instance!._initialized) {
        await _instance!._logSink?.close();
        _instance!._initialized = false;
        _instance!._logSink = null;
        _instance!._logFile = null;
      }
      
      final directory = await getApplicationDocumentsDirectory();
      
      // Clear current log
      final currentLog = File('${directory.path}/$_currentLogFile');
      if (await currentLog.exists()) {
        await currentLog.delete();
      }
      
      // Clear previous log
      final previousLog = File('${directory.path}/$_previousLogFile');
      if (await previousLog.exists()) {
        await previousLog.delete();
      }
      
      // Reinitialize logger
      await _instance?.initialize();
    } catch (e) {
      // ignore: avoid_print
      print('Failed to clear logs: $e');
    }
  }
  
  static Future<Map<String, String>> getLogPaths() async {
    final directory = await getApplicationDocumentsDirectory();
    return {
      'current': '${directory.path}/$_currentLogFile',
      'previous': '${directory.path}/$_previousLogFile',
    };
  }
}
