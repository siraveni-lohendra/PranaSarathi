import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AmbulanceLocationService {
  AmbulanceLocationService();

  final StreamController<Position> _positionController =
      StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  StreamSubscription<Position>? _gpsSubscription;

  bool get isTracking => _gpsSubscription != null;

  Future<bool> ensurePermissions() async {
    // Check whether device GPS/location service is enabled.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return false;
    }

    // Check current location permission.
    var permission = await Geolocator.checkPermission();

    // Request permission if required.
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // User permanently denied permission.
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // User denied permission.
    if (permission == LocationPermission.denied) {
      return false;
    }

    // Make sure Android permission_handler also reports permission.
    var androidPermission = await Permission.locationWhenInUse.status;

    if (!androidPermission.isGranted) {
      androidPermission = await Permission.locationWhenInUse.request();

      if (!androidPermission.isGranted) {
        return false;
      }
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final allowed = await ensurePermissions();

    if (!allowed) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return position;
    } catch (_) {
      return null;
    }
  }

  Future<bool> startTracking() async {
    final allowed = await ensurePermissions();

    if (!allowed) {
      return false;
    }

    // Avoid multiple GPS streams.
    await stopTracking();

    _gpsSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (position) {
            if (!_positionController.isClosed) {
              _positionController.add(position);
            }
          },
          onError: (_) {
            // Ignore a single GPS stream error.
          },
        );

    return true;
  }

  Future<void> stopTracking() async {
    await _gpsSubscription?.cancel();
    _gpsSubscription = null;
  }

  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }

  void dispose() {
    unawaited(stopTracking());
    _positionController.close();
  }
}
