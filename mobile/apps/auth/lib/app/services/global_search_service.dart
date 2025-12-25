import 'package:ente_auth/utils/platform_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

class GlobalSearchService with WindowListener {
  static final GlobalSearchService instance = GlobalSearchService._privateConstructor();
  GlobalSearchService._privateConstructor();

  final Logger _logger = Logger("GlobalSearchService");

  // State
  final ValueNotifier<bool> isMiniMode = ValueNotifier(false);
  Size? _previousSize;
  Offset? _previousPosition;
  bool _isInitialized = false;
  DateTime _lastToggleTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isTransitioning = false;

  Future<void> init() async {
    if (!PlatformUtil.isDesktop() || _isInitialized) return;
    
    windowManager.addListener(this);

    await hotKeyManager.unregisterAll();
    
    // Register Default Hotkey (Cmd+Shift+Space)
    HotKey hotKey = HotKey(
      key: LogicalKeyboardKey.space,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );
    
    try {
      await hotKeyManager.register(
        hotKey,
        keyDownHandler: (hotKey) {
          _toggleMiniMode();
        },
      );
    } catch (e) {
      _logger.severe("Failed to register hotkey", e);
    }
    
    _isInitialized = true;
  }

  @override
  void onWindowBlur() {
    if (isMiniMode.value && !_isTransitioning) {
      _autoClose();
    }
  }

  Future<void> _autoClose() async {
    await exitMiniMode(restoreFocus: false, hide: true);
  }
  
  Future<void> _toggleMiniMode() async {
    final now = DateTime.now();
    if (now.difference(_lastToggleTime).inMilliseconds < 300) {
      return;
    }
    _lastToggleTime = now;

    if (isMiniMode.value) {
      await exitMiniMode();
    } else {
      await enterMiniMode();
    }
  }

  Future<void> enterMiniMode() async {
    if (isMiniMode.value) return;
    _isTransitioning = true;
    
    // Save current window state
    _previousSize = await windowManager.getSize();
    _previousPosition = await windowManager.getPosition();
    
    isMiniMode.value = true;
    
    // Resize and Center
    // Assuming 600x400 for mini mode
    await windowManager.setSize(const Size(600, 400));
    await windowManager.center();
    await windowManager.setSkipTaskbar(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await windowManager.focus();
    
    // Allow window state to settle
    Future.delayed(const Duration(milliseconds: 500), () {
      _isTransitioning = false;
    });
  }

  Future<void> exitMiniMode({bool restoreFocus = true, bool hide = true}) async {
    if (!isMiniMode.value) return;

    if (hide) {
      await windowManager.hide();
    }

    isMiniMode.value = false;
    
    // Restore window state
    if (_previousSize != null) {
      await windowManager.setSize(_previousSize!);
    }
    if (_previousPosition != null) {
      await windowManager.setPosition(_previousPosition!);
    }
    
    await windowManager.setSkipTaskbar(false);
    await windowManager.setAlwaysOnTop(false);
    if (restoreFocus && !hide) {
      await windowManager.focus();
    }
  }
}
