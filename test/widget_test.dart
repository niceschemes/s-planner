import 'dart:convert';

import 'package:curso/main.dart';
import 'package:curso/src/geocoder.dart';
import 'package:curso/src/models.dart';
import 'package:curso/src/place.dart';
import 'package:curso/src/planner_controller.dart';
import 'package:curso/src/screens/import_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets('a tela de hoje mostra a rota e inicia a execução', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlannerController(
      geocoder: Geocoder(client: _OkClient()),
      locate: () async => const Place(
        label: 'Rua do Teste, 10',
        latitude: -21.97,
        longitude: -46.79,
      ),
      history: <DayRoute>[],
    );

    await tester.pumpWidget(SPlannerApp(controller: controller));

    expect(find.byKey(const Key('app-title')), findsOneWidget);
    expect(find.text('Rota do dia'), findsOneWidget);
    expect(find.text('0/0'), findsOneWidget);
    expect(find.text('Cliente Ana'), findsNothing);
    expect(
      find.text('Importe as paradas para montar a sequência.'),
      findsOneWidget,
    );
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Adicionar manual'), findsOneWidget);

    final start = tester.widget<OutlinedButton>(
      find.byKey(const Key('start-route')),
    );
    expect(start.onPressed, isNull);
  });

  testWidgets('com paradas a home mostra a próxima e libera iniciar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlannerController(
      geocoder: Geocoder(client: _OkClient(), gap: Duration.zero),
      locate: () async => const Place(
        label: 'Rua do Teste, 10',
        latitude: -22.06,
        longitude: -46.97,
      ),
      history: <DayRoute>[],
    );

    await tester.pumpWidget(SPlannerApp(controller: controller));
    controller.addDrafts([
      DraftStop(
        client: 'Ana',
        address: 'Rua XV de Novembro 447, Aguaí',
        phone: '',
        note: '',
        clientUncertain: false,
        addressUncertain: false,
        duplicate: false,
        incomplete: false,
        invalid: false,
        lat: -22.06,
        lng: -46.97,
      ),
    ]);
    await tester.pump();

    expect(find.text('Próxima parada: Ana'), findsOneWidget);
    expect(
      find.text('Adicione paradas para montar a sequência.'),
      findsNothing,
    );
    expect(find.text('0/1'), findsOneWidget);
    final start = tester.widget<OutlinedButton>(
      find.byKey(const Key('start-route')),
    );
    expect(start.onPressed, isNotNull);
  });

  testWidgets('colar endereço não marca como inexistente antes do mapa', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlannerController(
      geocoder: Geocoder(client: _OkClient(), gap: Duration.zero),
      locate: () async =>
          const Place(label: 'Aqui', latitude: -22.06, longitude: -46.97),
      here: () async => const Place(
        label: 'Onde estou agora',
        latitude: -21.47,
        longitude: -47.00,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PlannerScope(controller: controller, child: const ImportPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mococa'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).at(1),
      'Ana - Rua XV de Novembro 447',
    );
    await tester.tap(find.text('Ler paradas'));
    await tester.pump();

    expect(find.text('Não achei no mapa'), findsNothing);
    expect(find.textContaining('Rua XV de Novembro 447, Mococa'), findsWidgets);
  });

  Future<PlannerController> openManual(
    WidgetTester tester,
    http.Client client,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PlannerController(
      geocoder: Geocoder(client: client, gap: Duration.zero),
      locate: () async =>
          const Place(label: 'Aqui', latitude: -22.06, longitude: -46.97),
      here: () async => const Place(
        label: 'Onde estou agora',
        latitude: -22.06,
        longitude: -46.97,
      ),
      history: <DayRoute>[],
    );
    await tester.pumpWidget(SPlannerApp(controller: controller));
    await tester.tap(find.text('Adicionar manual'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(
      find.widgetWithText(TextField, 'Digite ou cole os endereços'),
      'Ana - Rua XV de Novembro 447',
    );
    await tester.tap(find.text('Ler paradas'));
    await tester.pump();
    return controller;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'sem resposta do mapa o endereço digitado ainda vai para a rota',
    (tester) async {
      final controller = await openManual(tester, _DownClient());
      await tester.tap(find.text('Adicionar 1 paradas'));
      await settle(tester);

      expect(controller.today.visits, hasLength(1));
      expect(controller.today.visits.single.notLocated, isTrue);
      expect(find.text('Digite ou cole os endereços'), findsNothing);
    },
  );

  testWidgets('voltar depois de ler pergunta antes de perder os endereços', (
    tester,
  ) async {
    final controller = await openManual(tester, _OkClient());
    await tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
    await tester.pump();

    expect(find.text('Paradas não adicionadas'), findsOneWidget);
    await tester.tap(find.text('Adicionar'));
    await settle(tester);

    expect(controller.today.visits.map((visit) => visit.client), ['Ana']);
    expect(find.text('Digite ou cole os endereços'), findsNothing);
  });

  testWidgets('a tela interna tem voltar no Android e no iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      final controller = PlannerController(
        geocoder: Geocoder(client: _OkClient(), gap: Duration.zero),
        locate: () async =>
            const Place(label: 'Aqui', latitude: -22.06, longitude: -46.97),
        history: <DayRoute>[],
      );
      await tester.pumpWidget(SPlannerApp(controller: controller));
      await tester.tap(find.text('Adicionar manual'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byTooltip('Voltar'), findsOneWidget);
      expect(find.text('Digite ou cole os endereços'), findsOneWidget);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Digite ou cole os endereços'), findsNothing);
      expect(find.text('Adicionar manual'), findsOneWidget);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('voltar no Android sai de Planejar e fica na Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PlannerController(
      geocoder: Geocoder(client: _OkClient(), gap: Duration.zero),
      locate: () async =>
          const Place(label: 'Aqui', latitude: -22.06, longitude: -46.97),
      history: <DayRoute>[],
    );
    await tester.pumpWidget(SPlannerApp(controller: controller));
    await tester.tap(find.text('Planejar'));
    await tester.pump();
    expect(find.text('Nenhuma parada para organizar.'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pump();

    expect(find.text('Adicionar manual'), findsOneWidget);
    expect(find.text('Nenhuma parada para organizar.'), findsNothing);
  });
}

class _DownClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.contains('reverse')) {
      final bytes = utf8.encode('{"address":{"town":"Aguaí"}}');
      return http.StreamedResponse(Stream.value(bytes), 200, request: request);
    }
    return http.StreamedResponse(const Stream.empty(), 503, request: request);
  }
}

class _OkClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request.url.path.contains('reverse')
        ? '{"address":{"town":"Mococa"}}'
        : '[{"lat":"-21.96","lon":"-46.80"}]';
    final bytes = utf8.encode(body);
    return http.StreamedResponse(Stream.value(bytes), 200, request: request);
  }
}
