import 'dart:math' as math;

import 'package:curso/src/demo_route.dart';
import 'package:curso/src/place.dart';
import 'package:curso/src/route_optimizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const origin = Place(label: 'Saída', latitude: 0, longitude: 0);
  const near = Place(label: 'Perto', latitude: 0, longitude: 1);
  const far = Place(label: 'Longe', latitude: 0, longitude: 3);

  test('lista vazia não gera parada', () {
    final plan = bestRoute(origin, const []);
    expect(plan.stops, isEmpty);
    expect(plan.totalKm, 0);
  });

  test('visita a parada perto antes da longe', () {
    final plan = bestRoute(origin, const [far, near]);
    expect(plan.stops.map((stop) => stop.place.label), ['Perto', 'Longe']);
    expect(plan.messageFor(0), 'Você é a parada 1 de 2');
    expect(plan.messageFor(1), 'Você é a parada 2 de 2');
  });

  test('a sequência calculada é mais curta que a ordem anotada', () {
    const stops = [far, near];
    final plan = bestRoute(origin, stops);
    expect(plan.totalKm, lessThan(pathKm(origin, stops)));
  });

  test('cada parada entra uma vez', () {
    final plan = bestRoute(origin, const [far, near]);
    final labels = plan.stops.map((stop) => stop.place.label).toList();
    expect(labels.toSet(), hasLength(labels.length));
    expect(labels, ['Perto', 'Longe']);
  });

  test('o exemplo começa pela esquina mais próxima', () {
    final plan = bestRoute(demoOrigin, demoStops);
    expect(plan.stops.first.place.label, 'Esquina perto da saída');
    expect(plan.stops, hasLength(demoStops.length));
    expect(plan.totalKm, lessThanOrEqualTo(pathKm(demoOrigin, demoStops)));
  });

  test('acima de oito paradas ainda visita todas', () {
    final stops = List<Place>.generate(
      9,
      (index) => Place(label: 'P$index', latitude: 0, longitude: index + 1),
    );
    final plan = bestRoute(origin, stops);
    expect(plan.stops, hasLength(9));
    expect(plan.stops.map((stop) => stop.place.label).toSet(), hasLength(9));
    expect(plan.stops.first.place.label, 'P0');
  });

  test('com dez paradas não deixa um ponto isolado para o fim', () {
    const saida = Place(
      label: 'Saída',
      latitude: -22.0620,
      longitude: -46.9655,
    );
    const stops = [
      Place(label: 'C1', latitude: -22.0594143, longitude: -46.9776112),
      Place(label: 'C2', latitude: -22.0578962, longitude: -46.9750257),
      Place(label: 'C3', latitude: -22.0575946, longitude: -46.9659657),
      Place(label: 'C4', latitude: -22.0589538, longitude: -46.9809851),
      Place(label: 'C5', latitude: -22.0558049, longitude: -46.9732982),
      Place(label: 'C6', latitude: -22.0532768, longitude: -46.9820380),
      Place(label: 'C7', latitude: -22.0613132, longitude: -46.9746613),
      Place(label: 'C8', latitude: -22.0583349, longitude: -46.9785654),
      Place(label: 'C9', latitude: -22.0671181, longitude: -46.9743706),
      Place(label: 'C10', latitude: -22.0558565, longitude: -46.9749859),
    ];
    final plan = bestRoute(saida, stops);
    expect(plan.stops.map((stop) => stop.place.label), [
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

  test('com muitas paradas melhora a ida sempre para a mais próxima', () {
    final random = math.Random(7);
    final stops = List<Place>.generate(
      25,
      (index) => Place(
        label: 'P$index',
        latitude: -22.05 - random.nextDouble() * 0.03,
        longitude: -46.96 - random.nextDouble() * 0.03,
      ),
    );
    const saida = Place(label: 'Saída', latitude: -22.06, longitude: -46.96);
    final greedy = <Place>[];
    final remaining = [...stops];
    var current = saida;
    while (remaining.isNotEmpty) {
      remaining.sort(
        (a, b) =>
            haversineKm(
              current.latitude,
              current.longitude,
              a.latitude,
              a.longitude,
            ).compareTo(
              haversineKm(
                current.latitude,
                current.longitude,
                b.latitude,
                b.longitude,
              ),
            ),
      );
      current = remaining.removeAt(0);
      greedy.add(current);
    }
    final plan = bestRoute(saida, stops);
    expect(plan.stops.map((stop) => stop.place.label).toSet(), hasLength(25));
    expect(plan.totalKm, lessThan(pathKm(saida, greedy)));
  });
}
