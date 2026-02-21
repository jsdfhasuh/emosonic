import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../core/utils/logger.dart';
import 'audio_player_service.dart';

/// System tray service for Windows desktop
/// Manages tray icon, menu, and window behavior
class TrayService with TrayListener {
  static final TrayService _instance = TrayService._internal();
  factory TrayService() => _instance;
  TrayService._internal();

  final Logger _logger = Logger('TrayService');
  bool _isInitialized = false;
  AudioPlayerService? _audioService;

  /// Initialize tray service
  Future<void> initialize(AudioPlayerService audioService) async {
    if (_isInitialized) return;
    if (!Platform.isWindows) {
      _logger.info('TrayService only supported on Windows');
      return;
    }

    _audioService = audioService;

    try {
      // Set tray icon (using default Flutter icon for now)
      // You need to add assets/app_icon.ico to your project
      await trayManager.setIcon('assets/app_icon.ico');
      
      // Set tray menu
      await _setTrayMenu();
      
      // Listen to tray events
      trayManager.addListener(this);
      
      _isInitialized = true;
      _logger.info('TrayService initialized successfully');
    } catch (e) {
      _logger.error('Failed to initialize TrayService: $e');
    }
  }

  /// Set up tray menu
  Future<void> _setTrayMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'show',
          label: '显示主窗口',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'play_pause',
          label: '播放/暂停',
        ),
        MenuItem(
          key: 'previous',
          label: '上一曲',
        ),
        MenuItem(
          key: 'next',
          label: '下一曲',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit',
          label: '退出',
        ),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  @override
  void onTrayIconMouseDown() async {
    _logger.debug('Tray icon mouse down');
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() async {
    _logger.debug('Tray icon right mouse down');
    await trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    _logger.info('Tray menu clicked: ${menuItem.key}');
    
    switch (menuItem.key) {
      case 'show':
        await _showMainWindow();
        break;
      case 'play_pause':
        await _togglePlayPause();
        break;
      case 'previous':
        await _playPrevious();
        break;
      case 'next':
        await _playNext();
        break;
      case 'exit':
        await _exitApp();
        break;
    }
  }

  /// Show main window
  Future<void> _showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
    _logger.debug('Main window shown');
  }

  /// Toggle play/pause
  Future<void> _togglePlayPause() async {
    try {
      if (_audioService == null) return;
      if (_audioService!.player.playing) {
        await _audioService!.pause();
      } else {
        await _audioService!.play();
      }
    } catch (e) {
      _logger.error('Error toggling play/pause: $e');
    }
  }

  /// Play previous song
  Future<void> _playPrevious() async {
    try {
      if (_audioService == null) return;
      await _audioService!.playPrevious();
    } catch (e) {
      _logger.error('Error playing previous: $e');
    }
  }

  /// Play next song
  Future<void> _playNext() async {
    try {
      if (_audioService == null) return;
      await _audioService!.playNext();
    } catch (e) {
      _logger.error('Error playing next: $e');
    }
  }

  /// Exit application
  Future<void> _exitApp() async {
    _logger.info('Exiting app from tray');
    await trayManager.destroy();
    await windowManager.destroy();
    exit(0);
  }

  /// Show exit confirmation dialog
  static Future<bool> showExitConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出应用'),
        content: const Text('您希望最小化到系统托盘还是完全退出应用？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('最小化到托盘'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('退出应用'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Dispose tray service
  Future<void> dispose() async {
    if (!_isInitialized) return;
    trayManager.removeListener(this);
    await trayManager.destroy();
    _isInitialized = false;
    _logger.info('TrayService disposed');
  }
}
