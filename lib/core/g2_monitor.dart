import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class G2Incident {
  G2Incident({required this.kind, required this.clientKey, required this.occuredAt});
  final String kind, clientKey;
  final DateTime occuredAt;
}

/// Native Android records background and screen-off signals while exam is active.
/// Signals are observations, not proof of cheating. Users can appeal a penalty.
class G2Monitor with WidgetsBindingObserver {
  G2Monitor(this.onIncident);
  final Future<void> Function(G2Incident incident) onIncident;
  static const MethodChannel _channel = MethodChannel('eduhub/g2');
  final List<G2Incident> incidents = [];
  DateTime? _last;
  bool _active = false;
  bool _nativeAvailable = false;
  int _counter = 0;

  Future<void> start() async {
    if (_active) return;
    _active = true;
    WidgetsBinding.instance.addObserver(this);
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'violation') {
        final kind = (call.arguments is Map ? call.arguments['kind'] : null)?.toString() ?? 'app_background';
        await add(kind);
      }
    });
    try {
      await _channel.invokeMethod<void>('activate', {'active':true});
      _nativeAvailable = true;
    } on MissingPluginException {
      _nativeAvailable = false;
    } catch (_) {
      _nativeAvailable = false;
    }
  }

  Future<void> add(String kind) async {
    if (!_active) return;
    if (!{'app_background','screen_off','multi_window','focus_lost'}.contains(kind)) return;
    final now = DateTime.now();
    // One leave/resume event should not multiply the penalty.
    if (_last != null && now.difference(_last!).inMilliseconds.abs() < 1800) return;
    _last = now;
    final incident = G2Incident(kind:kind,clientKey:'${now.microsecondsSinceEpoch}-${++_counter}',occuredAt:now);
    incidents.add(incident);
    await onIncident(incident);
  }

  Future<void> _drainNative() async {
    if (!_nativeAvailable || !_active) return;
    try {
      final events = await _channel.invokeMethod<List<dynamic>>('drain');
      for (final item in events ?? const []) {
        if (item is String) await add(item);
      }
    } catch (_) { /* an event remains on native side until next drain */ }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_active) return;
    if (state == AppLifecycleState.resumed) {
      unawaited(_drainNative());
    } else if (!_nativeAvailable && state == AppLifecycleState.paused) {
      // Flutter desktop/browser fallback; Android uses native signals.
      unawaited(add('app_background'));
    }
  }

  Future<void> stop() async {
    if (!_active) return;
    // Collect queued Android incidents before removing protection.
    await _drainNative();
    _active = false;
    WidgetsBinding.instance.removeObserver(this);
    try { await _channel.invokeMethod<void>('activate', {'active':false}); } catch (_) {}
    _channel.setMethodCallHandler(null);
  }
}
