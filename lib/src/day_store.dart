import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'place.dart';

class StoredDay {
  const StoredDay({required this.today, required this.history});

  final DayRoute today;
  final List<DayRoute> history;
}

abstract class DayStore {
  Future<String?> read();
  Future<void> write(String payload);
}

class MemoryDayStore implements DayStore {
  String? payload;

  @override
  Future<String?> read() async => payload;

  @override
  Future<void> write(String payload) async {
    this.payload = payload;
  }
}

class PrefsDayStore implements DayStore {
  static const storageKey = 'splanner-day-v1';

  Future<void> _tail = Future<void>.value();

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    return raw;
  }

  @override
  Future<void> write(String payload) {
    _tail = _tail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, payload);
    });
    return _tail;
  }
}

String encodeDayState(DayRoute today, List<DayRoute> history) {
  return jsonEncode({
    'today': _day(today),
    'history': [for (final day in history) _day(day)],
  });
}

StoredDay? decodeDayState(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final data = jsonDecode(raw);
    if (data is! Map) return null;
    final today = data['today'];
    if (today is! Map) return null;
    final history = data['history'];
    return StoredDay(
      today: _readDay(today),
      history: [
        if (history is List)
          for (final item in history)
            if (item is Map) _readDay(item),
      ],
    );
  } catch (_) {
    return null;
  }
}

Map<String, Object?> _day(DayRoute day) {
  return {
    'id': day.id,
    'date': day.date.toIso8601String(),
    'origin': _place(day.origin),
    'company': _place(day.company),
    'home': _place(day.home),
    'visits': [for (final visit in day.visits) _visit(visit)],
    'endMode': day.endMode.name,
    'mode': day.mode.name,
    'closed': day.closed,
    'startMin': day.startMin,
    'reason': day.reason,
  };
}

Map<String, Object?> _place(Place place) {
  return {
    'label': place.label,
    'latitude': place.latitude,
    'longitude': place.longitude,
  };
}

Map<String, Object?> _visit(Visit visit) {
  return {
    'id': visit.id,
    'client': visit.client,
    'address': visit.address,
    'phone': visit.phone,
    'note': visit.note,
    'lat': visit.lat,
    'lng': visit.lng,
    'status': visit.status.name,
    'priority': visit.priority.name,
    'windowStartMin': visit.windowStartMin,
    'windowEndMin': visit.windowEndMin,
    'pinIndex': visit.pinIndex,
    'completedAt': visit.completedAt?.toIso8601String(),
    'rescheduleDate': visit.rescheduleDate?.toIso8601String(),
    'addressUncertain': visit.addressUncertain,
    'area': visit.area,
  };
}

DayRoute _readDay(Map<dynamic, dynamic> data) {
  final visits = data['visits'];
  return DayRoute(
    id: _text(data['id'], 'today'),
    date: DateTime.tryParse(_text(data['date'], '')) ?? DateTime.now(),
    origin: _readPlace(data['origin']),
    company: _readPlace(data['company']),
    home: _readPlace(data['home']),
    visits: [
      if (visits is List)
        for (final item in visits)
          if (item is Map) _readVisit(item),
    ],
    endMode: _enum(EndMode.values, data['endMode'], EndMode.lastClient),
    mode: _enum(OrganizeMode.values, data['mode'], OrganizeMode.curta),
    closed: data['closed'] == true,
    startMin: data['startMin'] is num ? (data['startMin'] as num).toInt() : 8 * 60,
    reason: _text(data['reason'], ''),
  );
}

Place _readPlace(Object? data) {
  if (data is! Map) {
    return const Place(label: '', latitude: -22.0597, longitude: -46.9786);
  }
  return Place(
    label: _text(data['label'], ''),
    latitude: data['latitude'] is num ? (data['latitude'] as num).toDouble() : -22.0597,
    longitude: data['longitude'] is num ? (data['longitude'] as num).toDouble() : -46.9786,
  );
}

Visit _readVisit(Map<dynamic, dynamic> data) {
  return Visit(
    id: _text(data['id'], 'v0'),
    client: _text(data['client'], 'Sem nome'),
    address: _text(data['address'], ''),
    phone: _text(data['phone'], ''),
    note: _text(data['note'], ''),
    lat: data['lat'] is num ? (data['lat'] as num).toDouble() : null,
    lng: data['lng'] is num ? (data['lng'] as num).toDouble() : null,
    status: _enum(StopStatus.values, data['status'], StopStatus.pending),
    priority: _enum(Priority.values, data['priority'], Priority.medium),
    windowStartMin: data['windowStartMin'] is num ? (data['windowStartMin'] as num).toInt() : null,
    windowEndMin: data['windowEndMin'] is num ? (data['windowEndMin'] as num).toInt() : null,
    pinIndex: data['pinIndex'] is num ? (data['pinIndex'] as num).toInt() : null,
    completedAt: DateTime.tryParse(_text(data['completedAt'], '')),
    rescheduleDate: DateTime.tryParse(_text(data['rescheduleDate'], '')),
    addressUncertain: data['addressUncertain'] == true,
    area: _text(data['area'], ''),
  );
}

String _text(Object? value, String fallback) => value is String ? value : fallback;

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}
