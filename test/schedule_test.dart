import 'package:curso/src/messages.dart';
import 'package:curso/src/models.dart';
import 'package:curso/src/place.dart';
import 'package:curso/src/schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const origin = Place(label: 'Saída', latitude: 0, longitude: 0);

  Visit stop(
    String id,
    String client,
    double lng, {
    Priority priority = Priority.medium,
    int? end,
  }) {
    return Visit(
      id: id,
      client: client,
      address: client,
      lat: 0,
      lng: lng,
      priority: priority,
      windowEndMin: end,
    );
  }

  DayRoute day(List<Visit> visits, {OrganizeMode mode = OrganizeMode.curta}) {
    return DayRoute(
      id: 'd',
      date: DateTime(2026, 9, 24),
      origin: origin,
      company: origin,
      home: const Place(label: 'Casa', latitude: 0, longitude: 0.2),
      visits: visits,
      mode: mode,
    );
  }

  test('modo curto visita o ponto perto antes do longe', () {
    final ordered = organizeVisits(
      [stop('far', 'Longe', 3), stop('near', 'Perto', 1)],
      origin,
      OrganizeMode.curta,
    );
    expect(ordered.map((visit) => visit.client), ['Perto', 'Longe']);
  });

  test('modo curto com dez paradas não deixa ponto isolado para o fim', () {
    const saida = Place(
      label: 'Saída',
      latitude: -22.0620,
      longitude: -46.9655,
    );
    const points = {
      'C1': (-22.0594143, -46.9776112),
      'C2': (-22.0578962, -46.9750257),
      'C3': (-22.0575946, -46.9659657),
      'C4': (-22.0589538, -46.9809851),
      'C5': (-22.0558049, -46.9732982),
      'C6': (-22.0532768, -46.9820380),
      'C7': (-22.0613132, -46.9746613),
      'C8': (-22.0583349, -46.9785654),
      'C9': (-22.0671181, -46.9743706),
      'C10': (-22.0558565, -46.9749859),
    };
    final visits = [
      for (final entry in points.entries)
        Visit(
          id: entry.key,
          client: entry.key,
          address: entry.key,
          lat: entry.value.$1,
          lng: entry.value.$2,
        ),
    ];
    final ordered = organizeVisits(visits, saida, OrganizeMode.curta);
    expect(ordered.map((visit) => visit.client), [
      'C3',
      'C5',
      'C10',
      'C6',
      'C4',
      'C8',
      'C1',
      'C2',
      'C7',
      'C9',
    ]);
  });

  test('prioridade alta fica na frente', () {
    final ordered = organizeVisits(
      [
        stop('low', 'Baixa', 0.2, priority: Priority.low),
        stop('high', 'Alta', 2, priority: Priority.high),
      ],
      origin,
      OrganizeMode.prioridade,
    );
    expect(ordered.first.client, 'Alta');
  });

  test('mover a parada perto para o fim aumenta o tempo', () {
    final before = measure(
      day([stop('near', 'Perto', 1), stop('far', 'Longe', 3)]),
    ).km;
    final after = measure(
      day([stop('far', 'Longe', 3), stop('near', 'Perto', 1)]),
    ).km;
    expect(after, greaterThan(before));
    expect(impactText(before, after), contains('adiciona'));
  });

  test('roteiro do motorista traz a ordem, observação e maps sem horário', () {
    final route = day([
      Visit(
        id: 'a',
        client: 'Ana',
        address: 'Rua X, 120',
        note: 'ligar antes',
        lat: 0,
        lng: 0.01,
      ),
    ]);
    final text = driverText(route, measure(route));
    expect(text, contains('Rota de hoje'));
    expect(text, contains('Ana'));
    expect(text, contains('Obs: ligar antes'));
    expect(text, contains('1. Ana'));
    expect(text, contains('Maps: https://www.google.com/maps/dir/'));
    expect(text, isNot(contains(':00')));
  });
}
