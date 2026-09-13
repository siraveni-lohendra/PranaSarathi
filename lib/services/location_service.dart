import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class AmbulanceLocationService {
  AmbulanceLocationService();

  final StreamController<Position> _positionController =
      StreamController.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  Future<bool> ensurePermissions() async {
    final permission = await Permission.locationWhenInUse.request();
    if (permission.isDenied) {
      final requested = await Permission.location.request();
      if (requested.isDenied) return false;
    }
    if (await Geolocator.isLocationServiceEnabled() == false) {
      return false;
    }
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await ensurePermissions();
    if (!hasPermission) return null;

    final location = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return location;
  }

  Future<StreamSubscription<Position>?> startTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    final stream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          _positionController.add(position);
        });

    return stream;
  }

  void dispose() {
    _positionController.close();
  }
}
