// =========================================================================
// ⚡ ADMIN LIVE UPDATES — one shared socket for every admin screen
//
//   final stop = AdminLive.on(['dropout_update', 'student_update'], () => _load(quiet: true));
//   ...
//   stop();   // in dispose()
//
// The socket joins "admin_room" (and joins again after every reconnect).
// When the connection comes back, every screen reloads once — nothing is missed.
// =========================================================================
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class AdminLive {
  AdminLive._();

  static IO.Socket? _socket;
  static final Map<String, Set<void Function()>> _listeners = {};
  static final Set<String> _wired = {};
  static const String _reconnected = '__reconnected__';

  static IO.Socket? _ensure() {
    if (_socket != null) return _socket;
    try {
      final uri = Uri.parse(ApiEndpoints.baseUrl);
      final s = IO.io('${uri.scheme}://${uri.host}:${uri.port}', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'forceNew': true,
        'reconnection': true,
        'auth': {'token': ApiHeaders.token ?? ''},
      });
      var first = true;
      s.onConnect((_) {
        s.emit('join_admin_room');
        if (!first) _fire(_reconnected); // missed events while offline → reload once
        first = false;
      });
      s.onReconnect((_) => s.emit('join_admin_room'));
      _socket = s;
    } catch (e) {
      debugPrint('Admin live updates off: $e');
    }
    return _socket;
  }

  static void _fire(String event) {
    for (final cb in List.of(_listeners[event] ?? const <void Function()>{})) {
      try {
        cb();
      } catch (_) {}
    }
  }

  /// Calls [onChange] whenever one of [events] arrives (many events in a row → one call).
  /// Returns a function that stops listening (call it in dispose).
  static void Function() on(List<String> events, void Function() onChange,
      {Duration debounce = const Duration(milliseconds: 600)}) {
    final s = _ensure();
    Timer? t;
    void cb() {
      t?.cancel();
      t = Timer(debounce, onChange);
    }

    for (final e in [...events, _reconnected]) {
      (_listeners[e] ??= <void Function()>{}).add(cb);
      if (e != _reconnected && s != null && _wired.add(e)) {
        s.on(e, (_) => _fire(e));
      }
    }
    return () {
      t?.cancel();
      for (final e in [...events, _reconnected]) {
        _listeners[e]?.remove(cb);
      }
    };
  }

  /// Logout: close the socket (next login opens a new one with the new token)
  static void reset() {
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _wired.clear();
  }
}
