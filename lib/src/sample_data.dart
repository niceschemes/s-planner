import 'models.dart';
import 'place.dart';

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

Place _point(String label, double lat, double lng) {
  return Place(label: label, latitude: lat, longitude: lng);
}

DayRoute buildEmptyToday() {
  final origin = _point('', -22.0597, -46.9786);
  return DayRoute(
    id: 'today',
    date: _day(0),
    origin: origin,
    company: origin,
    home: origin,
    visits: [],
    reason: '',
  );
}
