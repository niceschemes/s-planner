import 'models.dart';
import 'place.dart';
import 'route_optimizer.dart';

class StopEstimate {
  const StopEstimate({
    required this.legKm,
    required this.legMin,
    required this.arrivalMin,
  });

  final double legKm;
  final int legMin;
  final int arrivalMin;
}

class RouteStats {
  const RouteStats({
    required this.km,
    required this.driveMin,
    required this.serviceMin,
    required this.estimates,
  });

  final double km;
  final int driveMin;
  final int serviceMin;
  final Map<String, StopEstimate> estimates;

  int get plannedMin => driveMin + serviceMin;
}

const driveKmPerHour = 28.0;
const serviceMinPerStop = 60;

String fmtKm(double km) {
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

String fmtMin(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '${hours}h';
  return '${hours}h${rest.toString().padLeft(2, '0')}';
}

String fmtClock(int minutes) {
  final safe = minutes.clamp(0, 24 * 60 - 1);
  final hours = safe ~/ 60;
  final mins = safe % 60;
  return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
}

String formatDay(DateTime date) {
  const weeks = [
    'segunda',
    'terça',
    'quarta',
    'quinta',
    'sexta',
    'sábado',
    'domingo',
  ];
  const months = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${weeks[date.weekday - 1]}, ${date.day} ${months[date.month - 1]}';
}

int? parseClock(String raw) {
  final match = RegExp(r'^(\d{1,2})(?::(\d{2}))?$').firstMatch(raw.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2) ?? '0');
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

String impactText(double beforeKm, double afterKm) {
  final delta = afterKm - beforeKm;
  if (delta.abs() < 0.05) return 'A ordem mudou sem alterar a distância.';
  if (delta > 0) {
    return 'Mover esta parada adiciona ${fmtKm(delta)} ao trajeto.';
  }
  return 'Mover esta parada reduz ${fmtKm(-delta)} do trajeto.';
}

Visit? nextVisit(List<Visit> visits) {
  final open = visits.where((visit) => !visit.status.isClosed);
  for (final visit in open) {
    if (visit.status == StopStatus.enRoute) return visit;
  }
  for (final visit in open) {
    if (visit.status == StopStatus.pending ||
        visit.status == StopStatus.arrived ||
        visit.status == StopStatus.inService) {
      return visit;
    }
  }
  return null;
}

int sequenceNumber(DayRoute day, String id) {
  final open = day.visits
      .where((visit) => visit.status != StopStatus.cancelled)
      .toList();
  return open.indexWhere((visit) => visit.id == id) + 1;
}

List<Visit> upcomingAfter(DayRoute day) {
  final open = day.visits.where((visit) => !visit.status.isClosed).toList();
  final next = nextVisit(day.visits);
  if (next == null) return open.take(4).toList();
  final index = open.indexWhere((visit) => visit.id == next.id);
  if (index < 0) return open.take(4).toList();
  return open.skip(index + 1).take(4).toList();
}

RouteStats measure(DayRoute day) {
  var current = day.origin;
  var clock = day.startMin;
  var km = 0.0;
  var driveMin = 0;
  var serviceMin = 0;
  final estimates = <String, StopEstimate>{};

  for (final visit in day.visits) {
    if (visit.status == StopStatus.cancelled || !visit.hasPoint) continue;
    final leg = haversineKm(
      current.latitude,
      current.longitude,
      visit.lat!,
      visit.lng!,
    );
    final legMin = leg <= 0.05 ? 1 : (leg / driveKmPerHour * 60).round();
    clock += legMin;
    km += leg;
    driveMin += legMin;
    estimates[visit.id] = StopEstimate(
      legKm: leg,
      legMin: legMin,
      arrivalMin: clock,
    );
    clock += serviceMinPerStop;
    serviceMin += serviceMinPerStop;
    current = visit.asPlace();
  }

  if (day.endMode != EndMode.lastClient) {
    final dest = day.endMode == EndMode.company ? day.company : day.home;
    final leg = haversineKm(
      current.latitude,
      current.longitude,
      dest.latitude,
      dest.longitude,
    );
    final legMin = (leg / driveKmPerHour * 60).round();
    km += leg;
    driveMin += legMin;
  }

  return RouteStats(
    km: km,
    driveMin: driveMin,
    serviceMin: serviceMin,
    estimates: estimates,
  );
}

List<Visit> organizeVisits(
  List<Visit> visits,
  Place origin,
  OrganizeMode mode,
) {
  final done = visits
      .where((visit) => visit.status == StopStatus.done)
      .toList();
  final cancelled = visits
      .where((visit) => visit.status == StopStatus.cancelled)
      .toList();
  final rest = visits
      .where(
        (visit) =>
            visit.status != StopStatus.done &&
            visit.status != StopStatus.cancelled,
      )
      .toList();
  final ordered = switch (mode) {
    OrganizeMode.manual => rest,
    OrganizeMode.rapida => orderByNearest(origin, rest),
    OrganizeMode.curta => orderShortest(origin, rest),
    OrganizeMode.prioridade => orderByPriority(origin, rest),
    OrganizeMode.horarios => orderByWindow(rest),
  };
  return [...done, ...applyPins(ordered), ...cancelled];
}

String reasonFor(OrganizeMode mode, List<Visit> visits, RouteStats stats) {
  switch (mode) {
    case OrganizeMode.curta:
    case OrganizeMode.rapida:
      return 'Sequência otimizada para reduzir deslocamento.';
    case OrganizeMode.prioridade:
      final high = visits
          .where(
            (visit) =>
                visit.priority == Priority.high &&
                visit.status != StopStatus.cancelled,
          )
          .length;
      if (high == 0) return 'Nenhuma parada com prioridade alta.';
      return '$high paradas de prioridade alta ficam na frente.';
    case OrganizeMode.horarios:
      final respected = windowsRespected(visits, stats);
      if (respected == 0) return 'Nenhuma janela de horário definida.';
      return '$respected paradas respeitam janela de horário.';
    case OrganizeMode.manual:
      return 'Ordem definida manualmente.';
  }
}

int windowsRespected(List<Visit> visits, RouteStats stats) {
  var count = 0;
  for (final visit in visits) {
    if (visit.status == StopStatus.cancelled || !visit.hasWindow) continue;
    final arrival = stats.estimates[visit.id]?.arrivalMin;
    if (arrival == null) continue;
    final start = visit.windowStartMin ?? 0;
    final end = visit.windowEndMin ?? (24 * 60);
    if (arrival >= start && arrival <= end) count++;
  }
  return count;
}

bool outsideWindow(Visit visit, int? arrival) {
  if (!visit.hasWindow || arrival == null) return false;
  final start = visit.windowStartMin ?? 0;
  final end = visit.windowEndMin ?? (24 * 60);
  return arrival < start || arrival > end;
}

List<Visit> orderByNearest(Place origin, List<Visit> visits) {
  final pool = visits.where((visit) => visit.hasPoint).toList();
  final missing = visits.where((visit) => !visit.hasPoint).toList();
  var current = origin;
  final ordered = <Visit>[];
  while (pool.isNotEmpty) {
    var nearest = 0;
    var nearestKm = double.infinity;
    for (var i = 0; i < pool.length; i++) {
      final candidate = pool[i];
      final km = haversineKm(
        current.latitude,
        current.longitude,
        candidate.lat!,
        candidate.lng!,
      );
      if (km < nearestKm) {
        nearestKm = km;
        nearest = i;
      }
    }
    final next = pool.removeAt(nearest);
    ordered.add(next);
    current = next.asPlace();
  }
  return [...ordered, ...missing];
}

List<Visit> orderShortest(Place origin, List<Visit> visits) {
  final located = visits.where((visit) => visit.hasPoint).toList();
  final missing = visits.where((visit) => !visit.hasPoint).toList();
  if (located.isEmpty) return visits;
  final plan = bestRoute(
    origin,
    located.map((visit) => visit.asPlace()).toList(),
  );
  final byId = {for (final visit in located) visit.id: visit};
  final ordered = plan.stops.map((stop) => byId[stop.place.label]!).toList();
  return [...ordered, ...missing];
}

List<Visit> orderByPriority(Place origin, List<Visit> visits) {
  var current = origin;
  final ordered = <Visit>[];
  for (final priority in [Priority.high, Priority.medium, Priority.low]) {
    final group = visits.where((visit) => visit.priority == priority).toList();
    if (group.isEmpty) continue;
    final next = orderByNearest(current, group);
    ordered.addAll(next);
    Visit? lastPoint;
    for (final visit in next.reversed) {
      if (visit.hasPoint) {
        lastPoint = visit;
        break;
      }
    }
    if (lastPoint != null) current = lastPoint.asPlace();
  }
  return ordered;
}

List<Visit> orderByWindow(List<Visit> visits) {
  final copy = [...visits];
  copy.sort((a, b) {
    final aStart = a.windowStartMin ?? a.windowEndMin ?? (24 * 60 + 1);
    final bStart = b.windowStartMin ?? b.windowEndMin ?? (24 * 60 + 1);
    return aStart.compareTo(bStart);
  });
  return copy;
}

List<Visit> applyPins(List<Visit> ordered) {
  if (ordered.every((visit) => visit.pinIndex == null)) return ordered;
  final pinned = ordered.where((visit) => visit.pinIndex != null).toList()
    ..sort((a, b) => a.pinIndex!.compareTo(b.pinIndex!));
  final free = ordered.where((visit) => visit.pinIndex == null).toList();
  final result = List<Visit?>.filled(ordered.length, null);
  for (final visit in pinned) {
    var index = visit.pinIndex!.clamp(0, ordered.length - 1);
    var guard = 0;
    while (result[index] != null && guard < ordered.length) {
      index = (index + 1) % ordered.length;
      guard++;
    }
    result[index] = visit;
  }
  var freeIndex = 0;
  for (var i = 0; i < result.length; i++) {
    result[i] ??= free[freeIndex++];
  }
  return result.cast<Visit>();
}
