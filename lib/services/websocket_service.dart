import 'dart:async';
import 'dart:convert';

import 'package:ambulance_flutter/services/app_config.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
}

class WebSocketService {
  WebSocketService({required this.userId}) : _websocketUrl = '${AppConfig.websocketBaseUrl}/ws/$userId';

  final String userId;
  final String _websocketUrl;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<WebSocketConnectionStatus> _statusController =
      StreamController<WebSocketConnectionStatus>.broadcast();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  WebSocketConnectionStatus _status = WebSocketConnectionStatus.disconnected;
  bool _disposed = false;
  bool _connecting = false;

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<WebSocketConnectionStatus> get statusStream => _statusController.stream;
  WebSocketConnectionStatus get status => _status;

  Future<void> connect() async {
    if (_disposed || _connecting || _channel != null) {
      return;
    }

    _connecting = true;
    _setStatus(WebSocketConnectionStatus.connecting);

    try {
      final channel = WebSocketChannel.connect(Uri.parse(_websocketUrl));
      _channel = channel;
      _connecting = false;
      _setStatus(WebSocketConnectionStatus.connected);

      channel.stream.listen(
        (dynamic event) {
          try {
            final decoded = jsonDecode(event as String);
            if (decoded is Map<String, dynamic>) {
              _messageController.add(decoded);
              return;
            }
            if (decoded is Map) {
              _messageController.add(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {
            // Ignore malformed messages.
          }
        },
        onError: (_) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
      );
    } catch (_) {
      _connecting = false;
      _handleDisconnect();
    }
  }

  void _setStatus(WebSocketConnectionStatus next) {
    if (_disposed || _status == next) {
      return;
    }
    _status = next;
    if (!_statusController.isClosed) {
      _statusController.add(next);
    }
  }

  void _handleDisconnect() {
    if (_disposed) {
      return;
    }

    _channel = null;
    _setStatus(WebSocketConnectionStatus.disconnected);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      unawaited(connect());
    });
  }

  void send(Map<String, dynamic> message) {
    if (_channel == null) {
      return;
    }

    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (_) {
      _handleDisconnect();
    }
  }

  Future<void> close() async {
    _disposed = true;
    _reconnectTimer?.cancel();

    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
    }

    _setStatus(WebSocketConnectionStatus.disconnected);
  }

  void dispose() {
    unawaited(close());
    _messageController.close();
    _statusController.close();
  }
}
