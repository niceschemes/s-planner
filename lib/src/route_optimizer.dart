import 'dart:math' as math;

import 'place.dart';

class PlannedStop {
  const PlannedStop({required this.place, required this.legKm});

  final Place place;
  final double legKm;
}

class RoutePlan {
  const RoutePlan({required this.stops, required this.totalKm});

  final List<PlannedStop> stops;
  final double totalKm;

  int get count => stops.length;

  String messageFor(int index) {
    return 'Você é a parada ${index + 1} de $count';
  }
}

double _rad(double degrees) => degrees * math.pi / 180;

double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthKm = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double pathKm(Place origin, List<Place> order) {
  var total = 0.0;
  var current = origin;
  for (final stop in order) {
    total += haversineKm(
      current.latitude,
      current.longitude,
      stop.latitude,
      stop.longitude,
    );
    current = stop;
  }
  return total;
}

const _exactLimit = 12;

/// Ordena as paradas a partir da saída, sem volta ao início.
/// Até 12 endereços, acha a sequência mais curta.
/// Acima disso, parte da parada mais próxima e ajusta trechos enquanto encurtar.
RoutePlan bestRoute(Place origin, List<Place> stops) {
  if (stops.isEmpty) {
    return const RoutePlan(stops: [], totalKm: 0);
  }
  final order = stops.length <= _exactLimit
      ? _exact(origin, stops)
      : _improve(origin, _nearest(origin, stops));
  return _plan(origin, order);
}

double _km(Place a, Place b) =>
    haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);

List<Place> _exact(Place origin, List<Place> stops) {
  final n = stops.length;
  final full = (1 << n) - 1;
  final cost = List.filled((1 << n) * n, double.infinity);
  final from = List.filled((1 << n) * n, -1);
  for (var i = 0; i < n; i++) {
    cost[(1 << i) * n + i] = _km(origin, stops[i]);
  }
  for (var mask = 1; mask <= full; mask++) {
    for (var last = 0; last < n; last++) {
      final here = cost[mask * n + last];
      if (here == double.infinity) continue;
      for (var next = 0; next < n; next++) {
        if (mask & (1 << next) != 0) continue;
        final nextMask = mask | (1 << next);
        final value = here + _km(stops[last], stops[next]);
        if (value < cost[nextMask * n + next]) {
          cost[nextMask * n + next] = value;
          from[nextMask * n + next] = last;
        }
      }
    }
  }
  var last = 0;
  for (var i = 1; i < n; i++) {
    if (cost[full * n + i] < cost[full * n + last]) last = i;
  }
  final order = <Place>[];
  var mask = full;
  while (last >= 0) {
    order.add(stops[last]);
    final previous = from[mask * n + last];
    mask &= ~(1 << last);
    last = previous;
  }
  return order.reversed.toList();
}

List<Place> _improve(Place origin, List<Place> start) {
  var order = [...start];
  var best = pathKm(origin, order);
  var changed = true;
  while (changed) {
    changed = false;
    for (var i = 0; i < order.length - 1; i++) {
      for (var j = i + 1; j < order.length; j++) {
        final candidate = [
          ...order.sublist(0, i),
          ...order.sublist(i, j + 1).reversed,
          ...order.sublist(j + 1),
        ];
        final km = pathKm(origin, candidate);
        if (km < best - 1e-9) {
          order = candidate;
          best = km;
          changed = true;
        }
      }
    }
    for (var i = 0; i < order.length; i++) {
      for (var j = 0; j < order.length; j++) {
        if (i == j) continue;
        final candidate = [...order];
        candidate.insert(j, candidate.removeAt(i));
        final km = pathKm(origin, candidate);
        if (km < best - 1e-9) {
          order = candidate;
          best = km;
          changed = true;
        }
      }
    }
  }
  return order;
}

List<Place> _nearest(Place origin, List<Place> stops) {
  final remaining = [...stops];
  final order = <Place>[];
  var current = origin;
  while (remaining.isNotEmpty) {
    var nearestIndex = 0;
    var nearestKm = double.infinity;
    for (var i = 0; i < remaining.length; i++) {
      final candidate = remaining[i];
      final km = haversineKm(
        current.latitude,
        current.longitude,
        candidate.latitude,
        candidate.longitude,
      );
      if (km < nearestKm) {
        nearestKm = km;
        nearestIndex = i;
      }
    }
    final next = remaining.removeAt(nearestIndex);
    order.add(next);
    current = next;
  }
  return order;
}

RoutePlan _plan(Place origin, List<Place> order) {
  final planned = <PlannedStop>[];
  var current = origin;
  var total = 0.0;
  for (final stop in order) {
    final leg = haversineKm(
      current.latitude,
      current.longitude,
      stop.latitude,
      stop.longitude,
    );
    total += leg;
    planned.add(PlannedStop(place: stop, legKm: leg));
    current = stop;
  }
  return RoutePlan(stops: planned, totalKm: total);
}
