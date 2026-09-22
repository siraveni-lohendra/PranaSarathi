import 'dart:async';
import 'dart:math' as math;

import 'package:ambulance_flutter/models/destination.dart';
import 'package:ambulance_flutter/models/location_point.dart';
import 'package:ambulance_flutter/services/app_config.dart';
import 'package:ambulance_flutter/services/backend_service.dart';
import 'package:ambulance_flutter/services/google_maps_service.dart';
import 'package:ambulance_flutter/services/location_service.dart';
import 'package:ambulance_flutter/services/websocket_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.token,
    required this.userName,
    required this.userId,
  });

  final String token;
  final String userName;
  final String userId;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final AmbulanceLocationService _locations = AmbulanceLocationService();
  final GoogleMapsService _googleMaps = GoogleMapsService();
  final BackendService _backendService = BackendService();
  late final WebSocketService _webSocketService;

  final TextEditingController _searchController = TextEditingController();

  final Set<Marker> _markers = <Marker>{};
  final Set<Polyline> _polylines = <Polyline>{};

  GoogleMapController? _mapController;
  Timer? _locationSyncTimer;

  CameraPosition _cameraPosition = const CameraPosition(
    target: LatLng(17.3850, 78.4867),
    zoom: 14,
  );

  bool _loading = true;
  bool _gpsEnabled = false;
  bool _emergencyActive = false;

  bool _searchingHospitals = false;
  bool _calculatingRoute = false;

  String _statusText = 'STARTING';
  WebSocketConnectionStatus _webSocketStatus =
      WebSocketConnectionStatus.disconnected;

  LocationPoint? _currentLocation;
  Destination? _selectedDestination;
  List<Destination> _destinations = <Destination>[];

  StreamSubscription? _locationSub;

  double? _routeDistanceKm;
  String? _routeDurationText;

  DateTime? _lastSearchTime;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _webSocketService = WebSocketService(userId: widget.userId);

    _webSocketService.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _webSocketStatus = status);
    });

    unawaited(_webSocketService.connect());
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      if (mounted) {
        setState(() {
          _loading = true;
          _statusText = 'CHECKING GPS';
        });
      }

      final permissionGranted = await _locations.ensurePermissions();

      if (!permissionGranted) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _gpsEnabled = false;
          _statusText = 'GPS OFF';
        });

        _showMessage('Please enable GPS and location permission.');
        return;
      }

      _gpsEnabled = true;

      if (mounted) {
        setState(() {
          _statusText = 'GETTING LOCATION';
        });
      }

      final position = await _locations.getCurrentPosition();

      if (position != null) {
        final location = _positionToLocationPoint(position);
        _currentLocation = location;
        _cameraPosition = CameraPosition(target: location.toLatLng(), zoom: 16);
        _updateAmbulanceMarker(location);
        unawaited(_syncLocationToBackend());

        if (mounted) {
          setState(() {
            _statusText = 'GPS READY';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _gpsEnabled = false;
            _statusText = 'GPS ERROR';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _statusText = 'FINDING HOSPITALS';
        });
      }

      await _searchNearbyHospitals();

      if (!mounted) return;

      setState(() {
        _loading = false;
        _statusText = _currentLocation != null ? 'GPS LIVE' : 'GPS UNAVAILABLE';
      });

      final trackingStarted = await _locations.startTracking();
      if (!trackingStarted) {
        if (!mounted) return;
        setState(() {
          _gpsEnabled = false;
          _statusText = 'GPS OFF';
        });
        _showMessage('Unable to start live GPS tracking.');
        return;
      }

      _gpsEnabled = true;
      _locationSub = _locations.positionStream.listen(_handlePosition);
      _startLocationSyncTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _statusText = 'ERROR';
      });
      _showMessage('Initialization failed: $e');
    }
  }

  void _startLocationSyncTimer() {
    _locationSyncTimer?.cancel();
    _locationSyncTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_syncLocationToBackend());
    });
  }

  Future<void> _syncLocationToBackend() async {
    final location = _currentLocation;
    if (location == null) {
      return;
    }

    try {
      await _backendService.updateLocation(
        userId: widget.userId,
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } catch (_) {
      // Ignore backend outage here. The UI should continue to work.
    }
  }

  LocationPoint _positionToLocationPoint(dynamic position) {
    return LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed,
      heading: position.heading ?? 0.0,
      accuracy: position.accuracy,
      timestamp: DateTime.now(),
    );
  }

  void _handlePosition(dynamic position) {
    final location = _positionToLocationPoint(position);

    if (!mounted) return;

    setState(() {
      _currentLocation = location;
      _gpsEnabled = true;
      _statusText = _emergencyActive ? 'EMERGENCY ACTIVE' : 'GPS LIVE';
    });

    _updateAmbulanceMarker(location);

    if (_mapController != null && _emergencyActive) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: location.toLatLng(),
            zoom: 17,
            bearing: location.heading ?? 0.0,
          ),
        ),
      );
    }
  }

  void _updateAmbulanceMarker(LocationPoint location) {
    final marker = Marker(
      markerId: const MarkerId('ambulance'),
      position: location.toLatLng(),
      rotation: location.heading ?? 0.0,
      flat: true,
      anchor: const Offset(0.5, 0.5),
      infoWindow: const InfoWindow(
        title: 'Ambulance',
        snippet: 'Live GPS location',
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    if (!mounted) return;

    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'ambulance');
      _markers.add(marker);
    });
  }

  Future<void> _searchNearbyHospitals() async {
    final location = _currentLocation;
    if (location == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _searchingHospitals = true;
      });
    }

    try {
      final results = await _googleMaps.searchHospitals(
        'hospital',
        latitude: location.latitude,
        longitude: location.longitude,
      );

      final destinations = results
          .map((place) => Destination.fromGooglePlace(place))
          .toList();

      if (!mounted) return;

      setState(() {
        _destinations = destinations;
      });
    } catch (e) {
      debugPrint('Nearby hospital search error: $e');
      if (mounted) {
        _showMessage('Unable to load nearby hospitals.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _searchingHospitals = false;
        });
      }
    }
  }

  Future<void> _searchHospitals() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      await _searchNearbyHospitals();
      return;
    }

    final now = DateTime.now();
    if (_lastSearchTime != null &&
        now.difference(_lastSearchTime!) < const Duration(milliseconds: 500)) {
      return;
    }

    _lastSearchTime = now;

    if (mounted) {
      setState(() {
        _searchingHospitals = true;
      });
    }

    try {
      final location = _currentLocation;
      final results = await _googleMaps.searchHospitals(
        query,
        latitude: location?.latitude,
        longitude: location?.longitude,
      );

      final destinations = results
          .map((place) => Destination.fromGooglePlace(place))
          .toList();

      if (!mounted) return;

      setState(() {
        _destinations = destinations;
      });

      if (destinations.isEmpty) {
        _showMessage('No hospitals found for "$query".');
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Hospital search failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _searchingHospitals = false;
        });
      }
    }
  }

  Future<void> _selectDestination(Destination destination) async {
    if (_emergencyActive) {
      return;
    }

    if (_currentLocation == null) {
      _showMessage('Current GPS location is not available.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _selectedDestination = destination;
      _calculatingRoute = true;
      _statusText = 'CALCULATING ROUTE';
    });

    _addDestinationMarker(destination);

    try {
      final origin = _currentLocation!;
      final route = await _googleMaps.calculateRoute(
        originLatitude: origin.latitude,
        originLongitude: origin.longitude,
        destinationLatitude: destination.latitude,
        destinationLongitude: destination.longitude,
      );

      if (!mounted) return;

      final distanceMeters = route['distanceMeters'];
      final duration = route['duration'];

      double? distanceKm;
      if (distanceMeters is num) {
        distanceKm = distanceMeters.toDouble() / 1000.0;
      }

      final durationText = _formatGoogleDuration(duration);
      final encodedPolyline = route['polyline']?['encodedPolyline'];
      final points = _decodePolyline(encodedPolyline?.toString() ?? '');

      setState(() {
        _routeDistanceKm = distanceKm;
        _routeDurationText = durationText;
        _calculatingRoute = false;
        _statusText = 'ROUTE READY';
      });

      if (points.isNotEmpty) {
        _drawRoute(points);
        _fitPointsOnMap(points);
      } else {
        _moveCameraToDestination(destination);
      }

      try {
        await _backendService.selectHospital(
          ambulanceId: widget.userId,
          hospitalId: 'HOS001',
          hospitalName: destination.name,
        );
      } catch (_) {
        _showMessage('Hospital notification could not be sent.');
      }

      _showMessage('Route calculated successfully.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _calculatingRoute = false;
        _statusText = 'GPS LIVE';
        _routeDistanceKm = null;
        _routeDurationText = null;
      });
      _showMessage('Unable to calculate route: $e');
    }
  }

  void _addDestinationMarker(Destination destination) {
    final marker = Marker(
      markerId: const MarkerId('destination'),
      position: LatLng(destination.latitude, destination.longitude),
      infoWindow: InfoWindow(
        title: destination.name,
        snippet: destination.address,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    if (!mounted) return;

    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == 'destination');
      _markers.add(marker);
    });
  }

  void _drawRoute(List<LatLng> points) {
    if (points.isEmpty || !mounted) {
      return;
    }

    setState(() {
      _polylines.removeWhere(
        (polyline) => polyline.polylineId.value == 'route',
      );

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: Colors.green,
          width: 7,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    });
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];

    if (encoded.isEmpty) {
      return points;
    }

    int index = 0;
    int latitude = 0;
    int longitude = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      while (true) {
        if (index >= encoded.length) {
          return points;
        }

        final byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;

        if (byte < 0x20) {
          break;
        }
      }

      final deltaLatitude = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      latitude += deltaLatitude;

      shift = 0;
      result = 0;

      while (true) {
        if (index >= encoded.length) {
          return points;
        }

        final byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;

        if (byte < 0x20) {
          break;
        }
      }

      final deltaLongitude = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      longitude += deltaLongitude;

      points.add(LatLng(latitude / 100000.0, longitude / 100000.0));
    }

    return points;
  }

  String _formatGoogleDuration(dynamic duration) {
    if (duration == null) {
      return 'ETA unavailable';
    }

    final value = duration.toString();
    final match = RegExp(r'(\d+(?:\.\d+)?)s').firstMatch(value);

    if (match == null) {
      return 'ETA unavailable';
    }

    final seconds = double.tryParse(match.group(1)!) ?? 0;
    final minutes = math.max(1, (seconds / 60).round());

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '$hours hr';
    }

    return '$hours hr $remainingMinutes min';
  }

  void _fitPointsOnMap(List<LatLng> points) {
    if (_mapController == null || points.length < 2) {
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    if ((maxLat - minLat).abs() < 0.0001) {
      maxLat += 0.0005;
      minLat -= 0.0005;
    }

    if ((maxLng - minLng).abs() < 0.0001) {
      maxLng += 0.0005;
      minLng -= 0.0005;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (_) {
      // Map may not be ready.
    }
  }

  void _moveCameraToDestination(Destination destination) {
    if (_mapController == null) {
      return;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(destination.latitude, destination.longitude),
        15,
      ),
    );
  }

  Future<void> _startEmergency() async {
    if (_emergencyActive) {
      return;
    }

    if (_currentLocation == null) {
      _showMessage('GPS location is required.');
      return;
    }

    if (_selectedDestination == null) {
      _showMessage('Please select a hospital first.');
      return;
    }

    if (_polylines.isEmpty) {
      _showMessage('Please calculate the route first.');
      await _selectDestination(_selectedDestination!);
      if (_polylines.isEmpty) {
        return;
      }
    }

    try {
      await _backendService.startAmbulanceEmergency(ambulanceId: widget.userId);
    } catch (_) {
      _showMessage('Backend emergency start failed.');
    }

    if (!mounted) return;

    setState(() {
      _emergencyActive = true;
      _statusText = 'EMERGENCY ACTIVE';
    });

    _showMessage('Emergency started.');
    _moveCameraToDestination(_selectedDestination!);
  }

  Future<void> _endEmergency() async {
    if (!_emergencyActive) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _emergencyActive = false;
      _statusText = _currentLocation != null ? 'GPS LIVE' : 'GPS UNAVAILABLE';
    });

    _showMessage('Emergency ended.');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    if (_currentLocation != null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!.toLatLng(), zoom: 16),
        ),
      );
    }
  }

  Future<void> _openGpsSettings() async {
    await _locations.openLocationSettings();
  }

  void _recenterMap() {
    final location = _currentLocation;
    if (location == null || _mapController == null) {
      return;
    }

    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location.toLatLng(),
          zoom: 17,
          bearing: location.heading ?? 0.0,
          tilt: 0,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshGpsStatus());
    }
  }

  Future<void> _refreshGpsStatus() async {
    final enabled = await _locations.ensurePermissions();

    if (!mounted) return;

    setState(() {
      _gpsEnabled = enabled;
    });

    if (enabled && !_locations.isTracking) {
      final started = await _locations.startTracking();
      if (started) {
        _locationSub?.cancel();
        _locationSub = _locations.positionStream.listen(_handlePosition);
      }
    }
  }

  String _websocketStatusText() {
    switch (_webSocketStatus) {
      case WebSocketConnectionStatus.connected:
        return 'Connected';
      case WebSocketConnectionStatus.connecting:
        return 'Connecting...';
      case WebSocketConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  Color _statusColor() {
    if (_emergencyActive) {
      return Colors.red;
    }
    if (_calculatingRoute) {
      return Colors.orange;
    }
    if (_webSocketStatus == WebSocketConnectionStatus.disconnected) {
      return Colors.grey;
    }
    if (_gpsEnabled) {
      return Colors.green;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ambulance: ${widget.userName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_statusText} • ${_websocketStatusText()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildHomeBody(),
    );
  }

  Widget _buildHomeBody() {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              if (!kIsWeb && AppConfig.hasGoogleMapsKey)
                GoogleMap(
                  initialCameraPosition: _cameraPosition,
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: _gpsEnabled,
                  myLocationButtonEnabled: false,
                  compassEnabled: true,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  trafficEnabled: _emergencyActive,
                  onMapCreated: _onMapCreated,
                )
              else
                _buildMapUnavailable(),

              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: _buildGpsStatusCard(),
              ),

              Positioned(
                top: 88,
                left: 12,
                right: 12,
                child: _buildDestinationSearch(),
              ),

              Positioned(
                right: 16,
                bottom: 18,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _recenterMap,
                  child: const Icon(Icons.my_location),
                ),
              ),

              if (_loading)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(_statusText),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildControlPanel(),
      ],
    );
  }

  Widget _buildMapUnavailable() {
    return Container(
      color: Colors.grey.shade100,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 56, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'Map is unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Check your Google Maps API key.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsStatusCard() {
    return Card(
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(
              _gpsEnabled ? Icons.gps_fixed : Icons.gps_off,
              color: _gpsEnabled ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _gpsEnabled ? 'GPS LIVE' : 'GPS UNAVAILABLE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _gpsEnabled ? Colors.green : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_locationText(), style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
            if (!_gpsEnabled)
              IconButton(
                onPressed: _openGpsSettings,
                icon: const Icon(Icons.settings),
              ),
          ],
        ),
      ),
    );
  }

  String _locationText() {
    final location = _currentLocation;
    if (location == null) {
      return 'Waiting for location...';
    }

    return '${location.latitude.toStringAsFixed(6)}, '
        '${location.longitude.toStringAsFixed(6)}';
  }

  Widget _buildDestinationSearch() {
    return Column(
      children: [
        Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          child: TextField(
            controller: _searchController,
            enabled: !_emergencyActive,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              unawaited(_searchHospitals());
            },
            decoration: InputDecoration(
              hintText: 'Search hospital...',
              prefixIcon: const Icon(Icons.local_hospital, color: Colors.red),
              suffixIcon: _searchingHospitals
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: _emergencyActive
                          ? null
                          : () {
                              unawaited(_searchHospitals());
                            },
                      icon: const Icon(Icons.search),
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
            ),
          ),
        ),
        if (_destinations.isNotEmpty && !_emergencyActive)
          _buildDestinationResults(),
      ],
    );
  }

  Widget _buildDestinationResults() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 4),
            color: Colors.black26,
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _destinations.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final destination = _destinations[index];

          return ListTile(
            dense: true,
            leading: const CircleAvatar(
              backgroundColor: Colors.red,
              child: Icon(Icons.local_hospital, color: Colors.white, size: 20),
            ),
            title: Text(
              destination.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              destination.address,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () {
              unawaited(_selectDestination(destination));
            },
          );
        },
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: Colors.black87,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelectedDestination(),
          const SizedBox(height: 10),
          if (_calculatingRoute)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Calculating best route...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          if (_selectedDestination != null && _routeDistanceKm != null)
            _buildRouteInfo(),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildStartButton()),
              const SizedBox(width: 10),
              Expanded(child: _buildEndButton()),
            ],
          ),
          const SizedBox(height: 10),
          _buildEmergencyInfo(),
        ],
      ),
    );
  }

  Widget _buildSelectedDestination() {
    final destination = _selectedDestination;

    if (destination == null) {
      return const Text(
        'No destination selected',
        style: TextStyle(color: Colors.white70, fontSize: 14),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_hospital, color: Colors.greenAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DESTINATION',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (destination.address.isNotEmpty)
                  Text(
                    destination.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white60, fontSize: 10),
                  ),
              ],
            ),
          ),
          if (!_emergencyActive)
            IconButton(
              onPressed: _clearDestination,
              icon: const Icon(Icons.close, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _routeInfoItem(
              Icons.route,
              '${_routeDistanceKm!.toStringAsFixed(1)} km',
              'DISTANCE',
            ),
          ),
          Container(width: 1, height: 32, color: Colors.white24),
          Expanded(
            child: _routeInfoItem(
              Icons.access_time,
              _routeDurationText ?? 'N/A',
              'ETA',
            ),
          ),
          Container(width: 1, height: 32, color: Colors.white24),
          Expanded(
            child: _routeInfoItem(
              Icons.traffic,
              _emergencyActive ? 'LIVE' : 'TRAFFIC',
              'ROUTE',
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeInfoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.greenAccent),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8)),
      ],
    );
  }

  Widget _buildStartButton() {
    return FilledButton.icon(
      onPressed:
          (_emergencyActive ||
              _currentLocation == null ||
              _selectedDestination == null ||
              _calculatingRoute)
          ? null
          : _startEmergency,
      icon: const Icon(Icons.warning_amber_rounded),
      label: Text(_emergencyActive ? 'ACTIVE' : 'START EMERGENCY'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.red.shade900,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildEndButton() {
    return FilledButton.icon(
      onPressed: _emergencyActive ? _endEmergency : null,
      icon: const Icon(Icons.stop_circle),
      label: const Text('END EMERGENCY'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.grey.shade700,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade900,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildEmergencyInfo() {
    return Row(
      children: [
        Expanded(
          child: _infoItem(
            Icons.route,
            _polylines.isNotEmpty ? 'ROUTE READY' : 'NO ROUTE',
          ),
        ),
        Expanded(
          child: _infoItem(
            Icons.location_on,
            _gpsEnabled ? 'GPS LIVE' : 'GPS OFF',
          ),
        ),
        Expanded(
          child: _infoItem(
            Icons.local_hospital,
            _selectedDestination == null ? 'NO HOSPITAL' : 'HOSPITAL SET',
          ),
        ),
      ],
    );
  }

  Widget _infoItem(IconData icon, String text) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 19),
        const SizedBox(height: 3),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 9),
        ),
      ],
    );
  }

  void _clearDestination() {
    if (!mounted || _emergencyActive) {
      return;
    }

    setState(() {
      _selectedDestination = null;
      _routeDistanceKm = null;
      _routeDurationText = null;
      _polylines.removeWhere(
        (polyline) => polyline.polylineId.value == 'route',
      );
      _markers.removeWhere((marker) => marker.markerId.value == 'destination');
      _statusText = _gpsEnabled ? 'GPS LIVE' : 'GPS UNAVAILABLE';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSyncTimer?.cancel();
    _locationSub?.cancel();
    _searchController.dispose();
    _locations.dispose();
    _backendService.dispose();
    _webSocketService.dispose();
    _mapController = null;
    super.dispose();
  }
}
