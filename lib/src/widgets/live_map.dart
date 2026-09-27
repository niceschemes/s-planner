import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../geocoder.dart';
import '../links.dart';
import '../models.dart';
import '../place.dart';
import '../planner_controller.dart';
import '../road_route.dart';
import '../theme.dart';
import 'common.dart';

bool get osmTilesEnabled => Platform.environment['FLUTTER_TEST'] != 'true';

class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.origin,
    required this.visits,
    this.highlightId,
    this.returnTo,
    this.router,
  });

  final Place origin;
  final List<Visit> visits;
  final String? highlightId;
  final Place? returnTo;
  final RoadRouter? router;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final MapController _controller = MapController();
  late final RoadRouter? _router =
      widget.router ?? (osmTilesEnabled ? RoadRouter() : null);

  late String _signature = _routeSignature(
    widget.origin,
    widget.visits,
    widget.returnTo,
  );
  late List<LatLng> _line = _anchorPoints();
  bool _street = false;
  bool _ready = false;
  int _ticket = 0;

  List<Visit> get _open => widget.visits
      .where((visit) => visit.status != StopStatus.cancelled)
      .toList();

  List<LatLng> _anchorPoints() {
    return [
      LatLng(widget.origin.latitude, widget.origin.longitude),
      for (final visit in _open)
        if (visit.hasPoint) LatLng(visit.lat!, visit.lng!),
      if (widget.returnTo != null)
        LatLng(widget.returnTo!.latitude, widget.returnTo!.longitude),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadRoad();
  }

  @override
  void didUpdateWidget(covariant LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _routeSignature(widget.origin, widget.visits, widget.returnTo);
    if (next == _signature) return;
    _signature = next;
    _line = _anchorPoints();
    _street = false;
    _loadRoad();
    if (_ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
  }

  Future<void> _loadRoad() async {
    final router = _router;
    final anchors = _anchorPoints();
    if (router == null || anchors.length < 2) return;
    final ticket = ++_ticket;
    final road = await router.drive([
      for (final point in anchors) RoadPoint(point.latitude, point.longitude),
    ]);
    if (!mounted || ticket != _ticket || road == null || road.length < 2) {
      return;
    }
    setState(() {
      _line = [for (final point in road) point.latLng];
      _street = true;
    });
    _fit();
  }

  void _fit() {
    if (!_ready) return;
    final points = _line.length >= 2 ? _line : _anchorPoints();
    if (points.isEmpty) return;
    _controller.fitCamera(
      CameraFit.bounds(
        bounds: _padded(points),
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
        maxZoom: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final anchors = _anchorPoints();
    final missing = _open
        .where((visit) => !visit.hasPoint && visit.address.trim().isNotEmpty)
        .toList();
    final route = mapsRouteFor(
      origin: widget.origin,
      visits: widget.visits,
      returnTo: widget.returnTo,
    );
    final center = anchors.isEmpty
        ? const LatLng(-22.0597, -46.9786)
        : anchors.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              initialCameraFit: anchors.length < 2
                  ? null
                  : CameraFit.bounds(
                      bounds: _padded(anchors),
                      padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                      maxZoom: 16,
                    ),
              backgroundColor: AppColors.map,
              keepAlive: true,
              onMapReady: () {
                _ready = true;
                _fit();
              },
            ),
            children: [
              if (osmTilesEnabled)
                ColorFiltered(
                  colorFilter: const ColorFilter.matrix(<double>[
                    0.32,
                    0.08,
                    0.04,
                    0,
                    8,
                    0.04,
                    0.40,
                    0.08,
                    0,
                    14,
                    0.04,
                    0.10,
                    0.36,
                    0,
                    18,
                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),
                  child: TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'br.curso.app.curso',
                  ),
                ),
              if (_line.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _line,
                      strokeWidth: 5,
                      color: AppColors.mint,
                      borderStrokeWidth: 2,
                      borderColor: const Color(0xFF08362F),
                    ),
                  ],
                ),
              MarkerLayer(markers: _markers(context)),
            ],
          ),
          Positioned(
            left: 8,
            bottom: missing.isEmpty ? 6 : 42,
            child: const Text(
              '© OpenStreetMap',
              style: TextStyle(
                color: Color(0xCCE7F3F0),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: _Chip(label: _street ? 'Ruas' : 'Linha direta'),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Column(
              children: [
                _MapButton(
                  icon: Icons.my_location,
                  tooltip: 'Usar onde estou',
                  onTap: () => _useHere(context),
                ),
                const SizedBox(height: 6),
                _MapButton(
                  icon: Icons.route,
                  tooltip: 'Rota no Maps',
                  onTap: route == null
                      ? null
                      : () => openExternal(context, route),
                ),
              ],
            ),
          ),
          if (missing.isNotEmpty)
            Positioned(
              left: 8,
              right: 8,
              bottom: 6,
              child: Material(
                color: AppColors.amberSoft,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => showVisitEditor(context, visit: missing.first),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Text(
                      missing.length == 1
                          ? '1 endereço não localizado. Toque para corrigir.'
                          : '${missing.length} endereços não localizados. Toque para corrigir.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Marker> _markers(BuildContext context) {
    final markers = <Marker>[
      Marker(
        point: LatLng(widget.origin.latitude, widget.origin.longitude),
        width: 16,
        height: 16,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF8EE7FF),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF042028), width: 2),
          ),
        ),
      ),
    ];
    for (var i = 0; i < _open.length; i++) {
      final visit = _open[i];
      if (!visit.hasPoint) continue;
      final hot = visit.id == widget.highlightId;
      markers.add(
        Marker(
          point: LatLng(visit.lat!, visit.lng!),
          width: hot ? 36 : 28,
          height: hot ? 36 : 28,
          child: GestureDetector(
            onTap: () {
              PlannerScope.of(context).select(visit.id);
              _openStop(context, visit);
            },
            child: _Pin(number: i + 1, hot: hot),
          ),
        ),
      );
    }
    return markers;
  }

  Future<void> _useHere(BuildContext context) async {
    try {
      await PlannerScope.of(context).useCurrentOrigin();
    } on GeocodeException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _openStop(BuildContext context, Visit visit) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visit.client,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                visit.address.isEmpty
                    ? 'Endereço não informado'
                    : visit.address,
              ),
              const SizedBox(height: 6),
              Text(
                visit.status.label,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: visitCanNavigate(visit)
                        ? () {
                            Navigator.pop(sheetContext);
                            openExternal(context, mapsForVisit(visit));
                          }
                        : null,
                    child: const Text('Google Maps'),
                  ),
                  OutlinedButton(
                    onPressed: visitCanNavigate(visit)
                        ? () {
                            Navigator.pop(sheetContext);
                            openExternal(context, wazeForVisit(visit));
                          }
                        : null,
                    child: const Text('Waze'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      showVisitEditor(context, visit: visit);
                    },
                    child: const Text('Corrigir endereço'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

String _routeSignature(Place origin, List<Visit> visits, Place? returnTo) {
  final buffer = StringBuffer('${origin.latitude},${origin.longitude}');
  for (final visit in visits) {
    if (visit.status == StopStatus.cancelled || !visit.hasPoint) continue;
    buffer.write('|${visit.id}:${visit.lat},${visit.lng}');
  }
  if (returnTo != null) {
    buffer.write('|r${returnTo.latitude},${returnTo.longitude}');
  }
  return buffer.toString();
}

LatLngBounds _padded(List<LatLng> points) {
  final bounds = LatLngBounds.fromPoints(points);
  if ((bounds.north - bounds.south).abs() >= 0.002 ||
      (bounds.east - bounds.west).abs() >= 0.002) {
    return bounds;
  }
  final center = points.first;
  return LatLngBounds(
    LatLng(center.latitude - 0.01, center.longitude - 0.01),
    LatLng(center.latitude + 0.01, center.longitude + 0.01),
  );
}

class _Pin extends StatelessWidget {
  const _Pin({required this.number, required this.hot});

  final int number;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: hot ? AppColors.mint : const Color(0xFF17343C),
        shape: BoxShape.circle,
        border: Border.all(
          color: hot ? const Color(0xFFD7FFF6) : const Color(0xFF3D8F86),
          width: hot ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.mint.withValues(alpha: hot ? 0.55 : 0.18),
            blurRadius: hot ? 12 : 4,
          ),
        ],
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: hot ? const Color(0xFF04241C) : AppColors.ink,
          fontSize: hot ? 14 : 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xCC10181C),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.mint,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xE610181C),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(
          icon,
          size: 18,
          color: onTap == null ? AppColors.muted : AppColors.mint,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
