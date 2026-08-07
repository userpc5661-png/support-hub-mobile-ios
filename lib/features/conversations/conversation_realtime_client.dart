import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/network/api_client.dart';

enum RealtimeConnectionState { connecting, connected, reconnecting, offline }

class ConversationRealtimeClient extends ChangeNotifier {
  ConversationRealtimeClient(this.api);

  final ApiClient api;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _retry;
  Timer? _watchdog;
  Timer? _fallbackTimer;
  bool _disposed = false;
  bool _polling = false;
  int _attempt = 0;
  String? _lastRevision;
  String? _lastEventId;
  RealtimeConnectionState state = RealtimeConnectionState.connecting;

  Stream<Map<String, dynamic>> get events => _events.stream;

  void start() {
    if (_disposed || _subscription != null) return;
    if (_fallbackTimer == null) {
      _setState(_attempt == 0
          ? RealtimeConnectionState.connecting
          : RealtimeConnectionState.reconnecting);
    }
    _armWatchdog(const Duration(seconds: 2));
    _subscription = api
        .eventStream('/conversations/events', lastEventId: _lastEventId)
        .listen(
      (event) {
        final eventId = event['id']?.toString();
        if (eventId != null && eventId.isNotEmpty) _lastEventId = eventId;
        _attempt = 0;
        _stopFallbackPolling();
        _armWatchdog(const Duration(seconds: 35));
        _setState(RealtimeConnectionState.connected);
        _events.add(event);
      },
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    _subscription?.cancel();
    _subscription = null;
    if (_disposed || _retry?.isActive == true) return;
    _attempt += 1;
    if (_fallbackTimer == null) {
      _setState(RealtimeConnectionState.reconnecting);
    }
    final exponent = _attempt <= 1 ? 0 : (_attempt >= 5 ? 4 : _attempt - 1);
    final seconds = 1 << exponent;
    _retry = Timer(Duration(seconds: seconds), start);
  }

  void _armWatchdog(Duration delay) {
    _watchdog?.cancel();
    if (_disposed) return;
    _watchdog = Timer(delay, _startFallbackPolling);
  }

  void _startFallbackPolling() {
    if (_disposed || _fallbackTimer != null) return;
    _pollRevision();
    _fallbackTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _pollRevision());
  }

  Future<void> _pollRevision() async {
    if (_disposed || _polling) return;
    _polling = true;
    try {
      final response = await api.getMap('/conversations/events/poll');
      final revision = response['revision']?.toString() ?? 'unknown';
      final changed = _lastRevision == null || revision != _lastRevision;
      _lastRevision = revision;
      _attempt = 0;
      _setState(RealtimeConnectionState.connected);
      if (changed && !_events.isClosed) {
        _events.add({
          'type': 'poll.changed',
          'revision': revision,
          'occurredAt': response['checkedAt'],
        });
      }
    } catch (_) {
      if (_subscription == null) {
        _setState(RealtimeConnectionState.reconnecting);
      }
    } finally {
      _polling = false;
    }
  }

  void _stopFallbackPolling() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
  }

  void _setState(RealtimeConnectionState value) {
    if (state == value || _disposed) return;
    state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _watchdog?.cancel();
    _stopFallbackPolling();
    _subscription?.cancel();
    _events.close();
    state = RealtimeConnectionState.offline;
    super.dispose();
  }
}
