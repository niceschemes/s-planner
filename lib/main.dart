import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/day_store.dart';
import 'src/planner_controller.dart';
import 'src/screens/shell.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = PlannerController(store: PrefsDayStore());
  await controller.restore();
  runApp(SPlannerApp(controller: controller));
  controller.refreshOrigin().ignore();
}

class SPlannerApp extends StatefulWidget {
  const SPlannerApp({super.key, this.controller});

  final PlannerController? controller;

  @override
  State<SPlannerApp> createState() => _SPlannerAppState();
}

class _SPlannerAppState extends State<SPlannerApp> {
  late final PlannerController _controller = widget.controller ?? PlannerController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlannerScope(
      controller: _controller,
      child: MaterialApp(
        title: 'S Planner',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: const Color(0x00000000),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const Shell(),
      ),
    );
  }
}
