import 'package:flutter/material.dart';

import '../links.dart';
import '../models.dart';
import '../planner_controller.dart';
import '../schedule.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/live_map.dart';
import '../widgets/route_mark.dart';
import 'import_page.dart';
import 'summary_page.dart';

String routeHeadline(DayRoute day, Visit? next) {
  final open = day.visits.any((visit) => visit.status != StopStatus.cancelled);
  if (!open) return 'Adicione paradas para montar a sequência.';
  if (next == null) return 'Todas as paradas desta rota foram encerradas.';
  if (next.area.isNotEmpty) return 'Comece pela região ${next.area}';
  return 'Próxima parada: ${next.client}';
}

class TodayPage extends StatelessWidget {
  const TodayPage({
    super.key,
    required this.onOpenPlan,
    required this.onOpenRun,
  });

  final VoidCallback onOpenPlan;
  final VoidCallback onOpenRun;

  @override
  Widget build(BuildContext context) {
    final controller = PlannerScope.of(context);
    final day = controller.today;
    final stats = controller.stats;
    final next = nextVisit(day.visits);
    final done = day.countOf(StopStatus.done);
    final shown = day.visits
        .where((visit) => visit.status != StopStatus.cancelled)
        .toList();
    final preview = shown.take(4).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        _Instrument(
          day: day,
          stats: stats,
          done: done,
          next: next,
          onOpenPlan: onOpenPlan,
          onOpenRun: onOpenRun,
        ),
        const SizedBox(height: 16),
        const Text(
          'Próximas paradas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (preview.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Importe as paradas para montar a sequência.',
              style: TextStyle(color: AppColors.muted),
            ),
          )
        else
          for (var i = 0; i < preview.length; i++)
            _StopTile(
              number: i + 1,
              visit: preview[i],
              estimate: stats.estimates[preview[i].id],
              next: next?.id == preview[i].id,
              last: i == preview.length - 1,
            ),
        if (shown.length > preview.length)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 40),
            child: Text(
              'Mais ${shown.length - preview.length} paradas na sequência',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          children: [
            TextButton(
              onPressed: () => showShareSheet(context, day),
              child: const Text('Compartilhar'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SummaryPage()),
              ),
              child: const Text('Fechar dia'),
            ),
          ],
        ),
      ],
    );
  }
}

class _Instrument extends StatefulWidget {
  const _Instrument({
    required this.day,
    required this.stats,
    required this.done,
    required this.next,
    required this.onOpenPlan,
    required this.onOpenRun,
  });

  final DayRoute day;
  final RouteStats stats;
  final int done;
  final Visit? next;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenRun;

  @override
  State<_Instrument> createState() => _InstrumentState();
}

class _InstrumentState extends State<_Instrument>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = routeMarkIsNight(DateTime.now());
    final routeLine = routeHeadline(widget.day, widget.next);
    final total = widget.day.openCount;
    final progress = total == 0 ? 0.0 : widget.done / total;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedBuilder(
              animation: _motion,
              builder: (context, _) =>
                  RouteMark(night: night, travel: _motion.value),
            ),
            _Metrics(
              total: total,
              done: widget.done,
              km: fmtKm(widget.stats.km),
              progress: progress,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routeLine,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    key: const Key('import-stops'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ImportPage(manualFirst: true),
                      ),
                    ),
                    child: const Text('Adicionar manual'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('import-pdf'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ImportPage(manualFirst: false),
                      ),
                    ),
                    child: const Text('Adicionar PDF'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: SizedBox(
                height: 230,
                child: LiveMap(
                  origin: widget.day.origin,
                  visits: widget.day.visits,
                  highlightId: widget.next?.id,
                  returnTo: widget.day.endMode == EndMode.lastClient
                      ? null
                      : widget.day.endMode == EndMode.company
                      ? widget.day.company
                      : widget.day.home,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton(
                    key: const Key('start-route'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: widget.next == null || !visitCanNavigate(widget.next!)
                        ? null
                        : () {
                            goToStop(context, widget.next!);
                            widget.onOpenRun();
                          },
                    child: Text(widget.done == 0 ? 'Iniciar rota' : 'Ir para a próxima parada'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const Key('organize-route'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                    onPressed: widget.onOpenPlan,
                    child: const Text('Organizar sequência'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({
    required this.total,
    required this.done,
    required this.km,
    required this.progress,
  });

  final int total;
  final int done;
  final String km;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rota do dia',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: const Color(0xFF243C44),
                        color: AppColors.mint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$done de $total feitas',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 58,
                height: 58,
                child: CustomPaint(
                  painter: _RingPainter(progress: progress),
                  child: Center(
                    child: Text(
                      '$done/$total',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(
                icon: Icons.place_outlined,
                value: '$total',
                label: 'Paradas',
              ),
              _Metric(icon: Icons.route, value: km, label: 'Distância'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.mint),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = const Color(0xFF243C44);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.mint;
    canvas.drawCircle(center, radius, track);
    final sweep = (progress.clamp(0, 1)) * 6.28318;
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.5708,
        sweep,
        false,
        arc,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StopTile extends StatelessWidget {
  const _StopTile({
    required this.number,
    required this.visit,
    required this.estimate,
    required this.next,
    required this.last,
  });

  final int number;
  final Visit visit;
  final StopEstimate? estimate;
  final bool next;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final minutes = estimate == null ? null : fmtKm(estimate!.legKm);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: next ? AppColors.mint : const Color(0xFF1C333A),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: next ? AppColors.mint : const Color(0xFF3D6A72),
                    ),
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      color: next ? const Color(0xFF04241C) : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(child: Container(width: 1, color: AppColors.line)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 10, top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.client,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    visit.address,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  if (visit.notLocated) const NotLocatedNote(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (minutes != null)
                  Text(
                    minutes,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  next ? 'Próxima' : 'Na fila',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: next ? AppColors.mint : AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
