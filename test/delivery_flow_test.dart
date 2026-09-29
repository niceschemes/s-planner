import 'package:curso/src/day_store.dart';
import 'package:curso/src/geocoder.dart';
import 'package:curso/src/models.dart';
import 'package:curso/src/place.dart';
import 'package:curso/src/planner_controller.dart';
import 'package:curso/src/sample_data.dart';
import 'package:curso/src/schedule.dart';
import 'package:curso/src/screens/import_page.dart';
import 'package:curso/src/screens/today_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  DraftStop draft(String client, double lat, double lng) {
    return DraftStop(
      client: client,
      address: client,
      phone: '',
      note: '',
      clientUncertain: false,
      addressUncertain: false,
      duplicate: false,
      incomplete: false,
      invalid: false,
      lat: lat,
      lng: lng,
    );
  }

  test('a saída é sempre a localização atual, mesmo com endereço salvo', () async {
    const gps = Place(label: 'Onde estou agora', latitude: -22.05, longitude: -46.97);
    final controller = PlannerController(
      geocoder: Geocoder(gap: Duration.zero),
      here: () async => gps,
    );
    controller.today.origin = const Place(
      label: 'Rua Antonio Paula Silva 168, Aguaí',
      latitude: -22.07,
      longitude: -46.99,
    );

    expect(await controller.refreshOrigin(), isTrue);
    expect(controller.today.origin.label, 'Onde estou agora');
    expect(controller.today.origin.latitude, -22.05);

    await controller.planImported([draft('Perto', -22.05, -46.96)]);
    expect(controller.today.origin.latitude, -22.05);
  });

  test('a saída vazia fica em Aguaí', () {
    final day = buildEmptyToday();
    expect(day.origin.latitude, closeTo(-22.06, 0.02));
    expect(day.origin.longitude, closeTo(-46.98, 0.02));
    expect(day.visits, isEmpty);
  });

  test('limpar endereços tira as paradas e o traçado da rota do dia', () {
    final controller = PlannerController(geocoder: Geocoder(gap: Duration.zero));
    controller.today.visits = [
      Visit(id: 'v1', client: 'Ana', address: 'Rua XV de Novembro 447', lat: -22.06, lng: -46.97),
    ];
    controller.tripStarted = true;

    controller.clearAddresses();

    expect(controller.today.visits, isEmpty);
    expect(controller.tripStarted, isFalse);
    expect(controller.today.reason, 'Cole ou adicione as paradas.');
  });

  test('a home pede parada só quando a rota está vazia', () {
    final empty = buildEmptyToday();
    expect(routeHeadline(empty, null), 'Adicione paradas para montar a sequência.');

    final day = buildEmptyToday();
    final next = Visit(id: 'v1', client: 'Ana', address: 'Rua XV de Novembro 447');
    day.visits = [next];
    expect(routeHeadline(day, next), 'Próxima parada: Ana');
    next.area = 'Centro';
    expect(routeHeadline(day, next), 'Comece pela região Centro');

    next.status = StopStatus.done;
    expect(
      routeHeadline(day, null),
      'Todas as paradas desta rota foram encerradas.',
    );
  });

  test('endereço ainda não conferido não aparece como inexistente', () {
    final pending = DraftStop(
      client: 'Ana',
      address: 'Rua XV de Novembro 447, Aguaí',
      phone: '',
      note: '',
      clientUncertain: false,
      addressUncertain: false,
      duplicate: false,
      incomplete: false,
      invalid: false,
    );
    expect(draftWarnings(pending), isEmpty);

    pending.notFound = true;
    expect(draftWarnings(pending), ['Não achei no mapa']);
  });

  test('endereço não localizado continua na rota com aviso', () async {
    final controller = PlannerController(geocoder: Geocoder(gap: Duration.zero));
    controller.today.origin = const Place(label: 'Saída', latitude: 0, longitude: 0);
    final missing = DraftStop(
      client: 'Sem mapa',
      address: 'Rua Que Não Existe 99, Aguaí',
      phone: '',
      note: '',
      clientUncertain: false,
      addressUncertain: true,
      duplicate: false,
      incomplete: false,
      invalid: false,
      notFound: true,
    );

    await controller.planImported([draft('Perto', 0, 0.2), missing]);

    final clients = controller.today.visits.map((visit) => visit.client).toList();
    expect(clients, ['Perto', 'Sem mapa']);
    final kept = controller.today.visits.last;
    expect(kept.notLocated, isTrue);
    expect(kept.addressUncertain, isTrue);
  });

  test('importar manual organiza pela parada mais próxima', () async {
    final store = MemoryDayStore();
    final controller = PlannerController(
      geocoder: Geocoder(gap: Duration.zero),
      store: store,
    );
    controller.today.origin = const Place(label: 'Saída', latitude: 0, longitude: 0);

    await controller.planImported([
      draft('Longe', 0, 3),
      draft('Perto', 0, 0.2),
    ]);
    await controller.saved;

    expect(controller.today.visits.map((visit) => visit.client), ['Perto', 'Longe']);
    final next = PlannerController(
      geocoder: Geocoder(gap: Duration.zero),
      store: store,
    );
    await next.restore();
    expect(next.today.visits.map((visit) => visit.client), ['Perto', 'Longe']);
    expect(next.today.origin.label, 'Saída');
  });

  test('concluir a parada atual abre a seguinte', () {
    final controller = PlannerController(geocoder: Geocoder(gap: Duration.zero));
    controller.today.visits = [
      Visit(id: 'v1', client: 'Ana', address: 'Rua A 1', lat: 1, lng: 1),
      Visit(id: 'v2', client: 'Bruno', address: 'Rua B 2', lat: 2, lng: 2),
    ];
    controller.setStatus('v1', StopStatus.done);
    expect(nextVisit(controller.today.visits)!.client, 'Bruno');
    expect(controller.today.countOf(StopStatus.done), 1);
  });

  test('voltar do Maps passa para a próxima parada da lista', () {
    final controller = PlannerController(geocoder: Geocoder(gap: Duration.zero));
    controller.today.visits = [
      Visit(id: 'v1', client: 'Ana', address: 'Rua A 1', lat: 1, lng: 1),
      Visit(id: 'v2', client: 'Bruno', address: 'Rua B 2', lat: 2, lng: 2),
      Visit(id: 'v3', client: 'Carla', address: 'Rua C 3', lat: 3, lng: 3),
    ];

    controller.startNavigation('v1');
    expect(controller.finishNavigation(), isNull);
    expect(nextVisit(controller.today.visits)!.client, 'Ana');

    controller.startNavigation('v1');
    controller.appPaused();
    final left = controller.finishNavigation();
    expect(left!.visit.client, 'Ana');
    expect(nextVisit(controller.today.visits)!.client, 'Bruno');
    expect(controller.finishNavigation(), isNull);

    controller.undoLeave('v1', left.previous);
    expect(nextVisit(controller.today.visits)!.client, 'Ana');
  });

  test('texto quebrado de rota não apaga o dia vazio', () {
    expect(decodeDayState('nao-e-json'), isNull);
    expect(decodeDayState(''), isNull);
  });

  test('o dia salvo no aparelho volta com status e coordenada', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PrefsDayStore();
    final day = buildEmptyToday();
    day.origin = const Place(label: 'Onde estou agora', latitude: -22.06, longitude: -46.97);
    day.visits = [
      Visit(
        id: 'v9',
        client: 'Carla',
        address: 'Rua Valins 746, Aguaí',
        lat: -22.061,
        lng: -46.981,
        status: StopStatus.enRoute,
      ),
    ];
    await store.write(encodeDayState(day, [buildEmptyToday()]));

    final stored = decodeDayState(await store.read());
    expect(stored, isNotNull);
    expect(stored!.today.origin.label, 'Onde estou agora');
    expect(stored.today.visits.single.client, 'Carla');
    expect(stored.today.visits.single.status, StopStatus.enRoute);
    expect(stored.today.visits.single.lat, closeTo(-22.061, 0.0001));
    expect(stored.history, hasLength(1));
  });
}
