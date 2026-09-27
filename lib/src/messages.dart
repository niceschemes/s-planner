import 'links.dart';
import 'models.dart';
import 'schedule.dart';

String driverText(DayRoute day, RouteStats stats) {
  final buffer = StringBuffer('Rota de hoje\n');
  final open = day.visits.where((visit) => visit.status != StopStatus.cancelled);
  var number = 1;
  for (final visit in open) {
    buffer.writeln('$number. ${visit.client}');
    buffer.writeln(visit.address);
    if (visit.note.isNotEmpty) buffer.writeln('Obs: ${visit.note}');
    if (visitCanNavigate(visit)) buffer.writeln('Maps: ${mapsForVisit(visit)}');
    buffer.writeln();
    number++;
  }
  return buffer.toString().trim();
}

String managerText(DayRoute day, RouteStats stats) {
  final buffer = StringBuffer()
    ..writeln('Resumo do dia')
    ..writeln('Planejadas: ${day.openCount}')
    ..writeln('Concluídas: ${day.countOf(StopStatus.done)}')
    ..writeln('Ausentes: ${day.countOf(StopStatus.absent)}')
    ..writeln('Remarcadas: ${day.countOf(StopStatus.reschedule)}')
    ..writeln('Canceladas: ${day.countOf(StopStatus.cancelled)}')
    ..writeln('Km previstos: ${fmtKm(stats.km)}');

  final notes = day.visits.where((visit) {
    return visit.note.isNotEmpty &&
        (visit.status == StopStatus.absent ||
            visit.status == StopStatus.badAddress ||
            visit.status == StopStatus.reschedule);
  });
  if (notes.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('Observações');
    for (final visit in notes) {
      buffer.writeln('${visit.client}: ${visit.note}');
    }
  }
  return buffer.toString().trim();
}

String clientText(Visit visit) {
  final buffer = StringBuffer('Olá, ${visit.client}. Estamos a caminho.\n${visit.address}');
  if (visit.note.isNotEmpty) buffer.write('\nObs: ${visit.note}');
  return buffer.toString();
}
