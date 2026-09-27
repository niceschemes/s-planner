import 'package:geolocator/geolocator.dart';

import 'geocoder.dart';
import 'place.dart';

Future<Place> currentPlace() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) {
    throw GeocodeException(
      'O GPS está desligado. Digite o endereço de saída.',
    );
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw GeocodeException(
      'Sem permissão de localização. Digite o endereço de saída.',
    );
  }

  final position = await Geolocator.getCurrentPosition();
  return Place(
    label: 'Onde estou agora',
    latitude: position.latitude,
    longitude: position.longitude,
  );
}

Future<Place> locateHere(Geocoder geocoder) async {
  final gps = await currentPlace();
  try {
    return await geocoder.reverse(gps.latitude, gps.longitude);
  } catch (_) {
    return Place(
      label: 'Localização atual',
      latitude: gps.latitude,
      longitude: gps.longitude,
    );
  }
}
