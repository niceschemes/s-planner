import 'package:flutter/material.dart';

import '../messages.dart';
import '../models.dart';
import '../planner_controller.dart';
import '../schedule.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SummaryPage extends StatelessWidget {
  const SummaryPage({super.key, this.route, this.live = true});

  final DayRoute? route;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final day = route ?? controller.today;
    final stats = measure(day);
    final notes = day.visits.where((visit) {
      return visit.note.isNotEmpty &&
          (visit.status == StopStatus.absent ||
              visit.status == StopStatus.badAddress ||
              visit.status == StopStatus.reschedule);
    });

    return Scaffold(
      appBar: appPageBar(context, live ? 'Fechamento' : formatDay(day.date)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Metric(label: 'Planejadas', value: '${day.openCount}'),
              Metric(label: 'Concluídas', value: '${day.countOf(StopStatus.done)}'),
              Metric(label: 'Ausentes', value: '${day.countOf(StopStatus.absent)}'),
              Metric(label: 'Remarcadas', value: '${day.countOf(StopStatus.reschedule)}'),
              Metric(label: 'Canceladas', value: '${day.countOf(StopStatus.cancelled)}'),
              Metric(label: 'Km previstos', value: fmtKm(stats.km)),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('Observações', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final visit in notes)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${visit.client}: ${visit.note}'),
              ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => copyText(context, managerText(day, stats), 'Resumo copiado.'),
            child: const Text('Copiar resumo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => showShareSheet(context, day),
            child: const Text('Compartilhar'),
          ),
          if (live && !day.closed) ...[
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.mint),
              onPressed: () {
                controller.closeDay();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dia encerrado.')),
                );
              },
              child: const Text('Encerrar dia'),
            ),
          ],
          if (day.closed) ...[
            const SizedBox(height: 12),
            const Text('Dia encerrado.', style: TextStyle(color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}
