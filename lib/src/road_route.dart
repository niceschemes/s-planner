import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoadPoint {
  const RoadPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);
}

List<RoadPoint>? parseOsrmRoute(String body) {
  try {
    final data = jsonDecode(body);
    if (data is! Map || data['code'] != 'Ok') return null;
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final geometry = routes.first['geometry'];
    if (geometry is! Map) return null;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final points = <RoadPoint>[];
    for (final item in coordinates) {
      if (item is! List || item.length < 2) return null;
      final lng = item[0];
      final lat = item[1];
      if (lat is! num || lng is! num) return null;
      points.add(RoadPoint(lat.toDouble(), lng.toDouble()));
    }
    return points;
  } catch (_) {
    return null;
  }
}

class RoadRouter {
  RoadRouter({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<RoadPoint>?> drive(List<RoadPoint> stops) async {
    if (stops.length < 2) return stops;
    final path = stops
        .map((stop) => '${stop.longitude},${stop.latitude}')
        .join(';');
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$path?overview=full&geometries=geojson',
    );
    try {
      final response = await _client.get(
        uri,
        headers: const {
          'User-Agent': 'S Planner/1.0 (trabalho academico)',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode != 200) return null;
      return parseOsrmRoute(response.body);
    } catch (_) {
      return null;
    }
  }
}
