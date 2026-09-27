import 'package:flutter/material.dart';

import '../messages.dart';
import '../models.dart';
import '../planner_controller.dart';
import '../schedule.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'summary_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _search = TextEditingController();
  HistoryFilter _filter = HistoryFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final query = _search.text.trim().toLowerCase();
    final routes = [controller.today, ...controller.history].where((day) {
      final matchesQuery = query.isEmpty || day.visits.any((visit) => visit.client.toLowerCase().contains(query));
      final matchesFilter = switch (_filter) {
        HistoryFilter.all => true,
        HistoryFilter.done => day.countOf(StopStatus.done) > 0,
        HistoryFilter.absent => day.countOf(StopStatus.absent) > 0,
        HistoryFilter.reschedule => day.countOf(StopStatus.reschedule) > 0,
        HistoryFilter.cancelled => day.countOf(StopStatus.cancelled) > 0,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Buscar cliente',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            for (final filter in HistoryFilter.values)
              _FilterWord(
                label: _filterLabel(filter),
                selected: _filter == filter,
                onTap: () => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final day in routes) _HistoryTile(day: day),
        const SizedBox(height: 8),
        const Text('Clientes frequentes', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (controller.frequentClients.isEmpty)
          const Text(
            'Nenhum cliente ainda.',
            style: TextStyle(color: AppColors.muted),
          )
        else
          for (final visit in controller.frequentClients.take(12))
            InkWell(
              onTap: () {
                controller.reuseClient(visit);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${visit.client} entrou na rota de hoje.')),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(visit.client, style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (visit.address.trim().isNotEmpty)
                      Text(
                        visit.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  String _filterLabel(HistoryFilter filter) {
    return switch (filter) {
      HistoryFilter.all => 'Todas',
      HistoryFilter.done => 'Concluído',
      HistoryFilter.absent => 'Ausente',
      HistoryFilter.reschedule => 'Remarcar',
      HistoryFilter.cancelled => 'Cancelado',
    };
  }
}

class _FilterWord extends StatelessWidget {
  const _FilterWord({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.mint : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.ink : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.day});

  final DayRoute day;

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final stats = measure(day);
    final live = day.id == controller.today.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SummaryPage(route: day, live: live)),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        live ? 'Hoje · ${formatDay(day.date)}' : formatDay(day.date),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(day.closed ? 'Encerrada' : 'Em aberto', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${day.countOf(StopStatus.done)} concluídas · ${fmtKm(stats.km)}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () {
                        controller.duplicateRoute(day);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Rota copiada para hoje.')),
                        );
                      },
                      child: const Text('Duplicar'),
                    ),
                    TextButton(
                      onPressed: () => copyText(context, managerText(day, stats), 'Resumo copiado.'),
                      child: const Text('Exportar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
