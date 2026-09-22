import 'package:ambulance_flutter/services/websocket_service.dart';
import 'package:flutter/material.dart';

class HospitalScreen extends StatefulWidget {
  const HospitalScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  final String userId;
  final String userName;

  @override
  State<HospitalScreen> createState() => _HospitalScreenState();
}

class _HospitalScreenState extends State<HospitalScreen> {
  late final WebSocketService _webSocketService;
  final List<Map<String, dynamic>> _notifications = <Map<String, dynamic>>[];
  WebSocketConnectionStatus _connectionStatus =
      WebSocketConnectionStatus.disconnected;

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
      if (type == 'hospital_notification') {
        final item = <String, dynamic>{
          ...message,
          'received_at': DateTime.now().toIso8601String(),
        };
        if (!mounted) return;
        setState(() {
          _notifications.insert(0, item);
        });
      }
    });

    _webSocketService.connect();
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
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

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) {
      return 'just now';
    }
    try {
      final parsed = DateTime.parse(isoString);
      return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      appBar: AppBar(
        title: Text('Hospital: ${widget.userName}'),
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
                'Hospital Dashboard',
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
              if (_notifications.isEmpty)
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
                      Icon(Icons.local_hospital, color: Colors.green, size: 55),
                      SizedBox(height: 15),
                      Text(
                        'No incoming ambulance',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Emergency arrivals will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final notification = _notifications[index];
                      final ambulanceId = notification['ambulance_id'] ?? 'Unknown';
                      final hospitalName = notification['hospital_name'] ?? widget.userName;
                      final time = _formatTime(notification['received_at'] as String?);

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'INCOMING AMBULANCE',
                              style: TextStyle(
                                color: Colors.greenAccent.shade400,
                                fontSize: 12,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ambulance: $ambulanceId',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Hospital selected: $hospitalName',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Status: Emergency incoming',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Notification time: $time',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
