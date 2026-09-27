import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'place.dart';

abstract class GeocodeCache {
  Future<Place?> read(String key);
  Future<void> write(String key, Place place);
}

class MemoryGeocodeCache implements GeocodeCache {
  final Map<String, Place> items = {};

  @override
  Future<Place?> read(String key) async => items[key];

  @override
  Future<void> write(String key, Place place) async {
    items[key] = place;
  }
}

class PrefsGeocodeCache implements GeocodeCache {
  static const _storageKey = 'splanner-geocode-v1';

  Map<String, Place>? _items;
  SharedPreferences? _prefs;

  Future<void> _load() async {
    if (_items != null) return;
    _items = {};
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw);
      if (data is! Map) return;
      for (final entry in data.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final lat = value['lat'];
        final lng = value['lng'];
        if (lat is! num || lng is! num) continue;
        _items![entry.key.toString()] = Place(
          label: value['label'] is String
              ? value['label'] as String
              : entry.key.toString(),
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
        );
      }
    } catch (_) {
      _items = {};
    }
  }

  @override
  Future<Place?> read(String key) async {
    await _load();
    return _items![key];
  }

  @override
  Future<void> write(String key, Place place) async {
    await _load();
    _items![key] = place;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final payload = {
        for (final entry in _items!.entries)
          entry.key: {
            'label': entry.value.label,
            'lat': entry.value.latitude,
            'lng': entry.value.longitude,
          },
      };
      await _prefs!.setString(_storageKey, jsonEncode(payload));
    } catch (_) {}
  }
}

String geocodeKey(String query) {
  return query.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
