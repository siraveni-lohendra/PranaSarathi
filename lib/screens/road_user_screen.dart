import 'dart:async';

import 'package:ambulance_flutter/services/backend_service.dart';
import 'package:ambulance_flutter/services/location_service.dart';
import 'package:ambulance_flutter/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class RoadUserScreen extends StatefulWidget {
  const RoadUserScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  State<RoadUserScreen> createState() => _RoadUserScreenState();
}

class _RoadUserScreenState extends State<RoadUserScreen> {
  late final WebSocketService _webSocketService;
  final AmbulanceLocationService _locationService = AmbulanceLocationService();
  final BackendService _backendService = BackendService();
  final StreamController<Map<String, dynamic>> _alertsController =
      StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<Position>? _locationSub;
  WebSocketConnectionStatus _connectionStatus =
      WebSocketConnectionStatus.disconnected;
  Map<String, dynamic>? _activeAlert;

  @override
  void initState() {
    super.initState();
    _webSocketService = WebSocketService(userId: widget.userId);

    _webSocketService.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _connectionStatus = status);
    });

    _webSocketService.messageStream.listen((message) {
      final type = message['type'];
      if (type == 'ambulance_alert') {
        if (!mounted) return;
        setState(() {
          _activeAlert = message;
        });
        HapticFeedback.heavyImpact();
      }
    });

    unawaited(_initializeLocation());
    _webSocketService.connect();
  }

  Future<void> _initializeLocation() async {
    try {
      final permissionGranted = await _locationService.ensurePermissions();
      if (!permissionGranted) {
        if (!mounted) return;
        setState(() {
          _activeAlert = {
            'type': 'gps_error',
            'message': 'Location permission is required to receive emergency alerts.',
          };
        });
        return;
      }

      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        await _sendLocation(position);
      }

      final started = await _locationService.startTracking();
      if (started) {
        _locationSub = _locationService.positionStream.listen((position) {
          unawaited(_sendLocation(position));
        });
      }
    } catch (_) {
      // Ignore location startup errors; keep the app alive.
    }
  }

  Future<void> _sendLocation(Position position) async {
    try {
      await _backendService.updateLocation(
        userId: widget.userId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      // Backend may be unavailable. The screen should remain usable.
    }
  }

  String _statusLabel() {
    switch (_connectionStatus) {
      case WebSocketConnectionStatus.connected:
        return 'Connected';
      case WebSocketConnectionStatus.connecting:
        return 'Connecting...';
      case WebSocketConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  Color _statusColor() {
    switch (_connectionStatus) {
      case WebSocketConnectionStatus.connected:
        return Colors.green;
      case WebSocketConnectionStatus.connecting:
        return Colors.orange;
      case WebSocketConnectionStatus.disconnected:
        return Colors.red;
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _locationService.dispose();
    _backendService.dispose();
    _webSocketService.dispose();
    _alertsController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        title: Text('Road User: ${widget.userName}'),
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Chip(
              backgroundColor: _statusColor().withValues(alpha: 0.18),
              label: Text(
                _statusLabel(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Road User',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'User ID: ${widget.userId}',
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 20),
              if (_activeAlert != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🚨 EMERGENCY VEHICLE APPROACHING',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ambulance ${_activeAlert!['ambulance_id'] ?? 'Unknown'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Distance: ${_activeAlert!['distance_meters'] ?? 0} m',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _activeAlert!['message'] ??
                            'An ambulance is approaching nearby. Please give way.',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () {
                            setState(() => _activeAlert = null);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('UNDERSTOOD'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.blue,
                        size: 55,
                      ),
                      SizedBox(height: 15),
                      Text(
                        'No emergency nearby',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Ambulance alerts will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
