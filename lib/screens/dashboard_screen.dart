import 'dart:async';

import 'package:ambulance_flutter/models/hospital.dart';
import 'package:ambulance_flutter/models/location_point.dart';
import 'package:ambulance_flutter/services/backend_service.dart';
import 'package:ambulance_flutter/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.token,
    required this.userName,
  });

  final String token;
  final String userName;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _backend = BackendService();
  final _locations = AmbulanceLocationService();
  final Set<Marker> _markers = <Marker>{};
  final Set<Polyline> _polylines = <Polyline>{};
  GoogleMapController? _mapController;
  CameraPosition _cameraPosition = const CameraPosition(
    target: LatLng(17.3850, 78.4867),
    zoom: 14,
  );
  bool _loading = true;
  bool _emergencyActive = false;
  bool _gpsEnabled = false;
  String _statusText = 'READY';
  String? _sessionId;
  Hospital? _selectedHospital;
  LocationPoint? _currentLocation;
  List<Hospital> _hospitals = <Hospital>[];
  StreamSubscription? _locationSub;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await Permission.locationWhenInUse.request();
      _gpsEnabled = await Permission.locationWhenInUse.isGranted;
      if (_gpsEnabled) {
        final position = await _locations.getCurrentPosition();
        if (position != null) {
          final loc = LocationPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            speed: position.speed,
            heading: position.heading,
            accuracy: position.accuracy,
            timestamp: DateTime.now(),
          );
          setState(() {
            _currentLocation = loc;
            _cameraPosition = CameraPosition(target: loc.toLatLng(), zoom: 15);
          });
          _markers.add(
            Marker(
              markerId: const MarkerId('ambulance'),
              position: loc.toLatLng(),
              infoWindow: const InfoWindow(title: 'Ambulance'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            ),
          );
        }
      }

      final hospitals = await _backend.listHospitals(widget.token);
      setState(() {
        _hospitals = hospitals;
        _selectedHospital = hospitals.isNotEmpty ? hospitals.first : null;
        _loading = false;
      });

      _locationSub = await _locations.startTracking();
      _locationSub?.onData((position) {
        final loc = LocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          heading: position.heading,
          accuracy: position.accuracy,
          timestamp: DateTime.now(),
        );

        if (!mounted) return;
        setState(() {
          _currentLocation = loc;
          _statusText = 'GPS LIVE';
        });

        _markers.removeWhere((m) => m.markerId.value == 'ambulance');
        _markers.add(
          Marker(
            markerId: const MarkerId('ambulance'),
            position: loc.toLatLng(),
            infoWindow: const InfoWindow(title: 'Ambulance'),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        );

        if (_mapController != null && _emergencyActive) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(loc.toLatLng()));
        }

        if (_emergencyActive && _sessionId != null) {
          unawaited(
            _backend.sendTelemetry(
              token: widget.token,
              sessionId: _sessionId!,
              currentLocation: loc,
            ),
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location initialization failed: $e')),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _startEmergency() async {
    if (_selectedHospital == null || _currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS and hospital selection are required.'),
        ),
      );
      return;
    }

    try {
      final result = await _backend.startEmergency(
        token: widget.token,
        hospitalId: _selectedHospital!.id,
        currentLocation: _currentLocation!,
      );
      final sessionId = result['sessionId'] as String?;
      if (sessionId == null) {
        throw Exception('No emergency session returned');
      }

      setState(() {
        _sessionId = sessionId;
        _emergencyActive = true;
        _statusText = 'EMERGENCY ACTIVE';
      });

      final polylinePoints =
          (result['route'] is Map && result['route']['polyline'] is List)
          ? (result['route']['polyline'] as List)
                .map(
                  (point) => LatLng(
                    (point[0] as num).toDouble(),
                    (point[1] as num).toDouble(),
                  ),
                )
                .toList()
          : <LatLng>[];

      if (polylinePoints.isNotEmpty) {
        setState(() {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('route'),
              points: polylinePoints,
              color: Colors.green,
              width: 7,
            ),
          );
        });
      }

      if (_selectedHospital != null) {
        _markers.add(
          Marker(
            markerId: MarkerId('hospital-${_selectedHospital!.id}'),
            position: LatLng(
              _selectedHospital!.latitude,
              _selectedHospital!.longitude,
            ),
            infoWindow: InfoWindow(title: _selectedHospital!.name),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Emergency start failed: $e')));
    }
  }

  Future<void> _endEmergency() async {
    setState(() {
      _emergencyActive = false;
      _statusText = 'EMERGENCY ENDED';
    });
    if (_sessionId != null) {
      // session stop endpoint could be added here for full backend compatibility.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ambulance: ${widget.userName}'),
        actions: [
          Chip(
            label: Text(_statusText),
            backgroundColor: _emergencyActive ? Colors.red : Colors.green,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: _cameraPosition,
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black87,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'SELECT HOSPITAL',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Hospital>(
                        initialValue: _selectedHospital,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                        ),
                        items: _hospitals
                            .map(
                              (hospital) => DropdownMenuItem(
                                value: hospital,
                                child: Text(
                                  '${hospital.name} • ${hospital.distanceKm ?? 0} km',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (hospital) =>
                            setState(() => _selectedHospital = hospital),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _startEmergency,
                              icon: const Icon(Icons.warning_amber_rounded),
                              label: const Text('START EMERGENCY'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _endEmergency,
                              icon: const Icon(Icons.stop_circle),
                              label: const Text('END EMERGENCY'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.grey,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentLocation == null
                            ? 'GPS: UNAVAILABLE'
                            : 'GPS: ${_currentLocation!.latitude.toStringAsFixed(5)}, ${_currentLocation!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _backend.dispose();
    _locations.dispose();
    super.dispose();
  }
}
