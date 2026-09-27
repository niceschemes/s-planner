import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../links.dart';
import '../messages.dart';
import '../models.dart';
import '../planner_controller.dart';
import '../schedule.dart';
import '../theme.dart';

class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final apple = Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;
    return IconButton(
      tooltip: 'Voltar',
      onPressed: () => Navigator.of(context).maybePop(),
      icon: Icon(apple ? Icons.arrow_back_ios_new : Icons.arrow_back),
    );
  }
}

AppBar appPageBar(BuildContext context, String title) {
  final canPop = Navigator.of(context).canPop();
  return AppBar(
    automaticallyImplyLeading: false,
    leading: canPop ? const PageBackButton() : null,
    title: Text(title),
  );
}

class NotLocatedNote extends StatelessWidget {
  const NotLocatedNote({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.amber),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              'Endereço não localizado no mapa. Confira.',
              style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final StopStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = statusTone(status.name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(color: tone.fg, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class IndexMark extends StatelessWidget {
  const IndexMark({super.key, required this.number, this.active = false});

  final int number;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.mint : AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: active ? AppColors.mint : AppColors.line),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: active ? const Color(0xFF04241C) : AppColors.ink,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<bool> openExternal(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não foi possível abrir o link.')),
    );
  }
  return ok;
}

Future<void> goToStop(BuildContext context, Visit visit, {bool waze = false}) async {
  final controller = PlannerScope.of(context);
  controller.startNavigation(visit.id);
  final opened = await openExternal(context, waze ? wazeForVisit(visit) : mapsForVisit(visit));
  if (!opened) controller.navigatingTo = null;
}

Future<void> copyText(BuildContext context, String text, String confirmation) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(confirmation)));
}

Future<void> showShareSheet(BuildContext context, DayRoute day) async {
  final stats = measure(day);
  final next = nextVisit(day.visits);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Compartilhar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _ShareTile(
                title: 'Roteiro para motorista',
                onTap: () => copyText(context, driverText(day, stats), 'Roteiro copiado.'),
              ),
              _ShareTile(
                title: 'Resumo para gestor',
                onTap: () => copyText(context, managerText(day, stats), 'Resumo copiado.'),
              ),
              if (next != null)
                _ShareTile(
                  title: 'Mensagem para ${next.client}',
                  onTap: () => copyText(
                    context,
                    clientText(next),
                    'Mensagem copiada.',
                  ),
                ),
              _ShareTile(
                title: 'WhatsApp do roteiro',
                onTap: () => openExternal(context, whatsAppLink(driverText(day, stats))),
              ),
              if (next != null && next.phone.isNotEmpty)
                _ShareTile(
                  title: 'WhatsApp de ${next.client}',
                  onTap: () => openExternal(
                    context,
                    whatsAppLink(
                      clientText(next),
                      phone: next.phone,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

class _ShareTile extends StatelessWidget {
  const _ShareTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

Future<void> showVisitEditor(BuildContext context, {Visit? visit}) async {
  final controller = PlannerScope.of(context);
  final client = TextEditingController(text: visit?.client ?? '');
  final address = TextEditingController(text: visit?.address ?? '');
  final phone = TextEditingController(text: visit?.phone ?? '');
  final note = TextEditingController(text: visit?.note ?? '');
  final start = TextEditingController(
    text: visit?.windowStartMin == null ? '' : fmtClock(visit!.windowStartMin!),
  );
  final end = TextEditingController(
    text: visit?.windowEndMin == null ? '' : fmtClock(visit!.windowEndMin!),
  );
  var priority = visit?.priority ?? Priority.medium;
  var pinned = visit?.pinIndex != null;

  await showDialog<void>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setLocal) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            title: Text(visit == null ? 'Nova parada' : 'Editar parada'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: client, decoration: const InputDecoration(labelText: 'Cliente')),
                    const SizedBox(height: 8),
                    TextField(controller: address, decoration: const InputDecoration(labelText: 'Endereço')),
                    const SizedBox(height: 8),
                    TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefone')),
                    const SizedBox(height: 8),
                    TextField(controller: note, decoration: const InputDecoration(labelText: 'Observação')),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: start,
                            decoration: const InputDecoration(labelText: 'Janela início'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: end,
                            decoration: const InputDecoration(labelText: 'Janela fim'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Priority>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Prioridade'),
                      items: [
                        for (final item in Priority.values)
                          DropdownMenuItem(value: item, child: Text(item.label)),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setLocal(() => priority = value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fixar posição'),
                      value: pinned,
                      onChanged: (value) => setLocal(() => pinned = value),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  controller.saveVisit(
                    id: visit?.id,
                    client: client.text,
                    address: address.text,
                    phone: phone.text,
                    note: note.text,
                    priority: priority,
                    windowStartMin: parseClock(start.text),
                    windowEndMin: parseClock(end.text),
                    pinned: pinned,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      );
    },
  );

  client.dispose();
  address.dispose();
  phone.dispose();
  note.dispose();
  start.dispose();
  end.dispose();
}
