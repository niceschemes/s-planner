import 'models.dart';
import 'place.dart';

String mapsLink(String address) {
  return 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
}

String mapsPointLink(double latitude, double longitude) {
  return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
}

String wazeLink(String address) {
  return 'https://waze.com/ul?q=${Uri.encodeComponent(address)}&navigate=yes';
}

String wazePointLink(double latitude, double longitude) {
  return 'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes';
}

String? mapsRouteLink({
  required double originLat,
  required double originLng,
  required List<({double lat, double lng})> stops,
}) {
  if (stops.isEmpty) return null;
  final destination = stops.last;
  final via = stops.length == 1
      ? const <({double lat, double lng})>[]
      : stops.sublist(0, stops.length - 1).take(9);
  final buffer = StringBuffer('https://www.google.com/maps/dir/?api=1')
    ..write('&origin=$originLat,$originLng')
    ..write('&destination=${destination.lat},${destination.lng}')
    ..write('&travelmode=driving');
  if (via.isNotEmpty) {
    buffer.write('&waypoints=');
    buffer.write(via.map((point) => '${point.lat},${point.lng}').join('|'));
  }
  return buffer.toString();
}

String _mapsNavigate(String destination) {
  return 'https://www.google.com/maps/dir/?api=1'
      '&destination=$destination&travelmode=driving&dir_action=navigate';
}

String mapsForVisit(Visit visit) {
  if (visit.hasPoint) return _mapsNavigate('${visit.lat},${visit.lng}');
  return _mapsNavigate(Uri.encodeComponent(visit.address));
}

String wazeForVisit(Visit visit) {
  if (visit.hasPoint) return wazePointLink(visit.lat!, visit.lng!);
  return wazeLink(visit.address);
}

bool visitCanNavigate(Visit visit) =>
    visit.hasPoint || visit.address.trim().isNotEmpty;

String? mapsRouteFor({
  required Place origin,
  required List<Visit> visits,
  Place? returnTo,
}) {
  final stops = <({double lat, double lng})>[
    for (final visit in visits)
      if (visit.status != StopStatus.cancelled && visit.hasPoint)
        (lat: visit.lat!, lng: visit.lng!),
  ];
  if (returnTo != null) {
    stops.add((lat: returnTo.latitude, lng: returnTo.longitude));
  }
  return mapsRouteLink(
    originLat: origin.latitude,
    originLng: origin.longitude,
    stops: stops,
  );
}

String? telLink(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8) return null;
  return 'tel:+55$digits';
}

String whatsAppLink(String text, {String? phone}) {
  final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  final query = Uri.encodeComponent(text);
  if (digits.length >= 8) {
    final withCountry = digits.startsWith('55') ? digits : '55$digits';
    return 'https://wa.me/$withCountry?text=$query';
  }
  return 'https://wa.me/?text=$query';
}
