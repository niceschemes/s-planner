import 'package:flutter/material.dart';

import '../geocoder.dart';
import '../models.dart';
import '../planner_controller.dart';
import '../schedule.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/live_map.dart';

class PlanPage extends StatelessWidget {
  const PlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final day = controller.today;
    final stats = controller.stats;
    final shown = day.visits
        .where((visit) => visit.status != StopStatus.cancelled)
        .toList();

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (day.reason.isNotEmpty)
            Text(day.reason, style: const TextStyle(color: AppColors.muted)),
          if (controller.impactMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              controller.impactMessage!,
              style: const TextStyle(
                color: AppColors.petrol,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          _LocateBox(nextStop: nextVisit(day.visits)?.address),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: LiveMap(
              origin: day.origin,
              visits: day.visits,
              highlightId: controller.selectedId ?? nextVisit(day.visits)?.id,
              returnTo: day.endMode == EndMode.lastClient
                  ? null
                  : day.endMode == EndMode.company
                  ? day.company
                  : day.home,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                fmtKm(stats.km),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              TextButton(
                onPressed: controller.canUndo ? controller.undo : null,
                child: const Text('Desfazer'),
              ),
              TextButton(
                onPressed: () => showVisitEditor(context),
                child: const Text('Adicionar'),
              ),
              TextButton(
                onPressed: () => controller.organize(day.mode),
                child: const Text('Recalcular'),
              ),
            ],
          ),
        ],
      ),
    );

    if (shown.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
        children: [
          header,
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nenhuma parada para organizar.'),
          ),
        ],
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      header: header,
      itemCount: shown.length,
      onReorderItem: controller.reorderShown,
      itemBuilder: (context, index) {
        final visit = shown[index];
        final estimate = stats.estimates[visit.id];
        final selected = controller.selectedId == visit.id;
        return Material(
          key: ValueKey(visit.id),
          color: selected ? AppColors.mintSoft : Colors.transparent,
          child: ListTile(
            onTap: () => controller.select(visit.id),
            leading: ReorderableDragStartListener(
              index: index,
              child: IndexMark(
                number: index + 1,
                active: selected || visit.status == StopStatus.enRoute,
              ),
            ),
            title: Text(
              visit.client,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_planMeta(visit, estimate)),
                if (visit.notLocated) const NotLocatedNote(),
              ],
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: visit.pinIndex == null ? 'Fixar' : 'Soltar',
                  onPressed: () => controller.togglePin(visit.id),
                  icon: Icon(
                    visit.pinIndex == null
                        ? Icons.push_pin_outlined
                        : Icons.push_pin,
                  ),
                ),
                PopupMenuButton<Priority>(
                  tooltip: 'Prioridade',
                  onSelected: (value) =>
                      controller.setPriority(visit.id, value),
                  itemBuilder: (context) => [
                    for (final priority in Priority.values)
                      PopupMenuItem(
                        value: priority,
                        child: Text(priority.label),
                      ),
                  ],
                  icon: const Icon(Icons.flag_outlined),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: () => showVisitEditor(context, visit: visit),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _planMeta(Visit visit, StopEstimate? estimate) {
  final bits = <String>[visit.status.label];
  if (estimate != null) bits.add(fmtKm(estimate.legKm));
  if (visit.priority != Priority.medium) bits.add(visit.priority.label);
  return '${visit.address}\n${bits.join(' · ')}';
}

class _LocateBox extends StatefulWidget {
  const _LocateBox({required this.nextStop});

  final String? nextStop;

  @override
  State<_LocateBox> createState() => _LocateBoxState();
}

class _LocateBoxState extends State<_LocateBox> {
  bool _busy = false;
  bool _shown = false;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PlannerScope.of(context).locateDeparture();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _shown = true;
      });
    } on GeocodeException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Não consegui ler o endereço.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final here = PlannerScope.of(context).today.origin.label.trim();
    final next = widget.nextStop?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: _busy ? null : _go,
          child: Text(_busy ? 'Localizando' : 'Localizar'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        ],
        if (_shown) ...[
          const SizedBox(height: 14),
          const Text('Onde estamos', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 2),
          Text(here.isEmpty ? 'Localização atual' : here),
          const SizedBox(height: 12),
          const Text('Para onde ir', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 2),
          Text(next.isEmpty ? 'Nenhuma parada na rota.' : next),
        ],
      ],
    );
  }
}
