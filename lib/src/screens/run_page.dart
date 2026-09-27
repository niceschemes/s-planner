import 'package:flutter/material.dart';

import '../links.dart';
import '../models.dart';
import '../planner_controller.dart';
import '../schedule.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'summary_page.dart';

class RunPage extends StatelessWidget {
  const RunPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final day = controller.today;
    final next = nextVisit(day.visits);
    final stats = controller.stats;
    final upcoming = upcomingAfter(day);

    if (next == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nada em aberto nesta rota.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryPage())),
                child: const Text('Ver resumo'),
              ),
            ],
          ),
        ),
      );
    }

    final estimate = stats.estimates[next.id];
    final number = sequenceNumber(day, next.id);
    final phone = telLink(next.phone);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text('Parada $number de ${day.openCount}', style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 6),
        Text(next.client, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.1)),
        const SizedBox(height: 8),
        Text(next.address, style: const TextStyle(fontSize: 18)),
        if (next.notLocated) const NotLocatedNote(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            if (estimate != null) Text('${fmtKm(estimate.legKm)} até lá', style: const TextStyle(fontWeight: FontWeight.w700)),
            StatusBadge(status: next.status),
          ],
        ),
        if (next.note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(next.note, style: const TextStyle(fontSize: 16, color: AppColors.amber)),
        ],
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 520;
            final buttons = [
              _Action(
                label: 'Abrir Maps',
                icon: Icons.map_outlined,
                onPressed: visitCanNavigate(next) ? () => goToStop(context, next) : null,
              ),
              _Action(
                label: 'Abrir Waze',
                icon: Icons.navigation_outlined,
                onPressed: visitCanNavigate(next) ? () => goToStop(context, next, waze: true) : null,
              ),
              _Action(
                label: 'Ligar',
                icon: Icons.call_outlined,
                onPressed: phone == null ? null : () => openExternal(context, phone),
              ),
              _Action(
                label: 'Marcar status',
                icon: Icons.task_alt,
                filled: true,
                onPressed: () => _pickStatus(context, next),
              ),
            ];
            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final button in buttons) ...[button, const SizedBox(height: 8)],
                ],
              );
            }
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3.4,
              children: buttons,
            );
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => showVisitEditor(context, visit: next),
            child: const Text('Editar parada'),
          ),
        ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Depois', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final visit in upcoming)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: IndexMark(number: sequenceNumber(day, visit.id)),
              title: Text(visit.client),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(visit.address),
                  if (visit.notLocated) const NotLocatedNote(),
                ],
              ),
              trailing: StatusBadge(status: visit.status),
            ),
        ],
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryPage())),
          child: const Text('Finalizar dia'),
        ),
      ],
    );
  }

  Future<void> _pickStatus(BuildContext context, Visit visit) async {
    final controller = PlannerScope.of(context);
    final chosen = await showModalBottomSheet<StopStatus>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final status in StopStatus.values)
                ListTile(
                  title: Text(status.label),
                  trailing: visit.status == status ? const Icon(Icons.check, color: AppColors.mint) : null,
                  onTap: () => Navigator.pop(context, status),
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !context.mounted) return;

    if (chosen == StopStatus.absent) {
      final note = await _askText(context, 'O que aconteceu?', 'Cliente ausente');
      if (note == null || note.trim().isEmpty || !context.mounted) return;
      controller.setStatus(visit.id, chosen, note: note);
      return;
    }
    if (chosen == StopStatus.badAddress) {
      final address = await _askText(context, 'Endereço corrigido', 'Corrigir endereço', initial: visit.address);
      if (address == null || address.trim().isEmpty || !context.mounted) return;
      controller.setStatus(visit.id, chosen, address: address);
      return;
    }
    if (chosen == StopStatus.reschedule) {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
      );
      if (date == null || !context.mounted) return;
      controller.setStatus(visit.id, chosen, date: date);
      return;
    }
    if (chosen == StopStatus.cancelled) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cancelar parada'),
          content: const Text('Ela sai da sequência ativa e entra no resumo do dia.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar parada')),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    controller.setStatus(visit.id, chosen);
  }

  Future<String?> _askText(BuildContext context, String title, String label, {String? initial}) {
    final field = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: field, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, field.text), child: const Text('Salvar')),
        ],
      ),
    ).whenComplete(field.dispose);
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
    if (filled) {
      return FilledButton(
        style: FilledButton.styleFrom(backgroundColor: AppColors.mint, minimumSize: const Size.fromHeight(52)),
        onPressed: onPressed,
        child: child,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      onPressed: onPressed,
      child: child,
    );
  }
}
