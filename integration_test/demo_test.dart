import 'package:curso/main.dart';
import 'package:curso/src/place.dart';
import 'package:curso/src/planner_controller.dart';
import 'package:curso/src/schedule.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _aqui = Place(label: 'Onde estou', latitude: -22.0620, longitude: -46.9655);

const _paradas = [
  'Cliente 1 - Rua Sete de Setembro 100',
  'Cliente 2 - Rua XV de Novembro 447',
  'Cliente 3 - Avenida Miguel Biazzo 500',
  'Cliente 4 - Rua Joaquim José 100',
  'Cliente 5 - Rua Santos Dumont 200',
  'Cliente 6 - Rua Marechal Deodoro 300',
  'Cliente 7 - Rua Barão do Rio Branco 200',
  'Cliente 8 - Rua Major Braga 150',
  'Cliente 9 - Rua Carlos Gomes 100',
  'Cliente 10 - Rua José Bonifácio 100',
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds * 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done, {int seconds = 120}) async {
    for (var i = 0; i < seconds * 2 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  testWidgets('demonstração das telas', (tester) async {
    final controller = PlannerController(
      here: () async => _aqui,
      locate: () async => _aqui,
    );
    await tester.pumpWidget(SPlannerApp(controller: controller));
    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
    }
    await controller.refreshOrigin();
    await wait(tester, 4);
    await binding.takeScreenshot('01-home-vazia');

    await tester.tap(find.text('Adicionar manual'));
    await waitFor(tester, () => find.text('Aguaí').evaluate().isNotEmpty, seconds: 30);
    await wait(tester, 1);
    await binding.takeScreenshot('02-adicionar-manual');

    await tester.enterText(find.byType(TextField).at(1), _paradas.join('\n'));
    FocusManager.instance.primaryFocus?.unfocus();
    await wait(tester, 1);
    await tester.tap(find.text('Ler paradas'));
    await wait(tester, 2);
    await binding.takeScreenshot('03-paradas-lidas');

    final adicionar = find.textContaining('Adicionar 10');
    await tester.ensureVisible(adicionar);
    await wait(tester, 1);
    await tester.tap(adicionar);
    await waitFor(
      tester,
      () => controller.today.visits.length == 10 && controller.today.visits.every((v) => v.hasPoint),
    );
    await wait(tester, 8);
    await binding.takeScreenshot('04-home-rota');

    await tester.tap(find.text('Planejar'));
    await wait(tester, 5);
    await binding.takeScreenshot('05-planejar');

    await tester.tap(find.text('Executar'));
    await wait(tester, 3);
    await binding.takeScreenshot('06-executar');

    final primeira = nextVisit(controller.today.visits)!;
    controller.startNavigation(primeira.id);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await wait(tester, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await wait(tester, 2);
    await binding.takeScreenshot('07-voltou-do-maps');

    await tester.tap(find.text('Histórico'));
    await wait(tester, 2);
    await binding.takeScreenshot('08-historico');
  });
}
