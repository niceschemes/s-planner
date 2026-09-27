import 'dart:convert';

import 'package:http/http.dart' as http;

import 'address_scan.dart';
import 'geocode_cache.dart';
import 'place.dart';

class GeocodeException implements Exception {
  GeocodeException(this.message);

  final String message;

  @override
  String toString() => message;
}

class Geocoder {
  Geocoder({
    http.Client? client,
    this._cache,
    this.gap = const Duration(milliseconds: 1100),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final GeocodeCache? _cache;
  final Duration gap;
  static DateTime? _nextRequest;

  Future<void> _pace() async {
    if (gap <= Duration.zero) return;
    final now = DateTime.now();
    final next = _nextRequest;
    if (next != null && next.isAfter(now)) {
      await Future<void>.delayed(next.difference(now));
    }
    _nextRequest = DateTime.now().add(gap);
  }

  Future<Place> search(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      throw GeocodeException('Digite o endereço.');
    }
    final key = geocodeKey(text);
    final cached = await _cache?.read(key);
    if (cached != null) {
      return Place(
        label: text,
        latitude: cached.latitude,
        longitude: cached.longitude,
      );
    }

    final hit = await _lookup(text);
    if (hit == null) {
      throw GeocodeException(
        'Endereço não encontrado. Inclua rua, número e cidade.',
      );
    }
    final place = Place(label: text, latitude: hit.latitude, longitude: hit.longitude);
    await _cache?.write(key, place);
    return place;
  }

  Future<Place?> confirmAddress(String address) async {
    final text = address.trim();
    if (text.isEmpty) return null;
    final key = geocodeKey('ok:$text');
    final cached = await _cache?.read(key);
    if (cached != null) {
      return Place(label: text, latitude: cached.latitude, longitude: cached.longitude);
    }
    for (final query in geocodeQueries(text)) {
      final hit = await _lookup(query);
      if (hit == null) continue;
      if (!geocodeHitMatches(text, hit.displayName)) continue;
      final place = Place(label: text, latitude: hit.latitude, longitude: hit.longitude);
      await _cache?.write(key, place);
      return place;
    }
    return null;
  }

  Future<_GeoHit?> _lookup(String query) async {
    await _pace();
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'countrycodes': 'br',
    });
    final response = await _client.get(
      uri,
      headers: const {
        'User-Agent': 'S Planner/1.0 (trabalho academico)',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw GeocodeException('Não foi possível localizar esse endereço.');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! List || data.isEmpty || data.first is! Map) return null;
    final item = data.first as Map;
    final lat = item['lat'];
    final lng = item['lon'];
    final displayName = item['display_name'];
    if (lat is! String || lng is! String) return null;
    return _GeoHit(
      latitude: double.parse(lat),
      longitude: double.parse(lng),
      displayName: displayName is String ? displayName : '',
    );
  }

  Future<String?> cityAt(double latitude, double longitude) async {
    await _pace();
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
      'zoom': '10',
      'addressdetails': '1',
    });
    final response = await _client.get(
      uri,
      headers: {
        'User-Agent': 'S Planner/1.0 (trabalho academico)',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map || data['address'] is! Map) return null;
    final address = data['address'] as Map;
    for (final key in ['city', 'town', 'village', 'municipality']) {
      final value = address[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Future<Place> reverse(double latitude, double longitude) async {
    final key = geocodeKey(
      'rev:${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}',
    );
    final cached = await _cache?.read(key);
    if (cached != null) return cached;

    await _pace();
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
    });
    final response = await _client.get(
      uri,
      headers: {
        'User-Agent': 'S Planner/1.0 (trabalho academico)',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode != 200) {
      throw GeocodeException('Não foi possível ler o endereço atual.');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map || data['display_name'] is! String) {
      throw GeocodeException('Não foi possível ler o endereço atual.');
    }
    final place = Place(
      label: data['display_name'] as String,
      latitude: latitude,
      longitude: longitude,
    );
    await _cache?.write(key, place);
    return place;
  }
}

class _GeoHit {
  const _GeoHit({required this.latitude, required this.longitude, required this.displayName});

  final double latitude;
  final double longitude;
  final String displayName;
}
