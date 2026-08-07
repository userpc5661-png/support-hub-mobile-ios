import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DockSettingsController extends ChangeNotifier {
  DockSettingsController._();

  static final DockSettingsController instance = DockSettingsController._();

  static const double defaultOpacity = .92;
  static const double defaultHeight = 56;
  static const double defaultBottomOffset = 4;

  static const _opacityKey = 'wasl_dock_opacity';
  static const _heightKey = 'wasl_dock_height';
  static const _bottomOffsetKey = 'wasl_dock_bottom_offset';

  bool _initialized = false;

  double opacity = defaultOpacity;
  double height = defaultHeight;
  double bottomOffset = defaultBottomOffset;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    opacity = (prefs.getDouble(_opacityKey) ?? defaultOpacity).clamp(.30, 1.0);
    height = (prefs.getDouble(_heightKey) ?? defaultHeight).clamp(46.0, 72.0);
    bottomOffset = (prefs.getDouble(_bottomOffsetKey) ?? defaultBottomOffset)
        .clamp(0.0, 32.0);

    notifyListeners();
  }

  void setOpacity(double value) {
    opacity = value.clamp(.30, 1.0);
    notifyListeners();
  }

  void setHeight(double value) {
    height = value.clamp(46.0, 72.0);
    notifyListeners();
  }

  void setBottomOffset(double value) {
    bottomOffset = value.clamp(0.0, 32.0);
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble(_opacityKey, opacity),
      prefs.setDouble(_heightKey, height),
      prefs.setDouble(_bottomOffsetKey, bottomOffset),
    ]);
  }

  Future<void> reset() async {
    opacity = defaultOpacity;
    height = defaultHeight;
    bottomOffset = defaultBottomOffset;
    notifyListeners();
    await save();
  }
}
