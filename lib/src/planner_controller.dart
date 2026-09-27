import 'package:flutter/widgets.dart';

import 'day_store.dart';
import 'geocode_cache.dart';
import 'geocoder.dart';
import 'location_service.dart';
import 'models.dart';
import 'place.dart';
import 'sample_data.dart';
import 'schedule.dart';

class _Snap {
  _Snap(this.ids, this.mode, this.reason);

  final List<String> ids;
  final OrganizeMode mode;
  final String reason;
}

class PlannerController extends ChangeNotifier {
  PlannerController({
    Geocoder? geocoder,
    Future<Place> Function()? locate,
    Future<Place> Function()? here,
    DayRoute? today,
    List<DayRoute>? history,
    this.store,
  }) : _geocoder = geocoder ?? Geocoder(cache: PrefsGeocodeCache()),
       _here = here ?? currentPlace,
       today = today ?? buildEmptyToday(),
       history = history ?? <DayRoute>[] {
    _locate = locate ?? () => locateHere(_geocoder);
    _noteIds();
  }

  final Geocoder _geocoder;
  final Future<Place> Function() _here;
  final DayStore? store;
  late final Future<Place> Function() _locate;
  Future<void> _saved = Future<void>.value();
  bool _hydrating = false;

  Future<void> get saved => _saved;
  DayRoute today;
  bool tripStarted = false;
  bool locating = false;
  bool showPlan = false;
  bool originDirty = false;
  bool originReady = false;
  String? flowError;
  List<DayRoute> history;
  String? selectedId;
  String? impactMessage;
  final List<_Snap> _undo = [];
  int _seq = 200;

  String _newId() => 'v${_seq++}';

  RouteStats get stats => measure(today);

  Future<void> restore() async {
    final raw = await store?.read();
    final stored = decodeDayState(raw);
    if (stored == null) return;
    _hydrating = true;
    today = stored.today;
    history = stored.history;
    _noteIds();
    _hydrating = false;
    notifyListeners();
  }

  void _noteIds() {
    for (final day in [today, ...history]) {
      _noteId(day.id);
      for (final visit in day.visits) {
        _noteId(visit.id);
      }
    }
  }

  void _noteId(String id) {
    final match = RegExp(r'^v(\d+)$').firstMatch(id);
    if (match == null) return;
    final value = int.parse(match.group(1)!);
    if (value >= _seq) _seq = value + 1;
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    final dayStore = store;
    if (dayStore == null || _hydrating) return;
    final payload = encodeDayState(today, history);
    _saved = _saved.then((_) async {
      try {
        await dayStore.write(payload);
      } catch (_) {}
    });
  }

  void select(String id) {
    selectedId = id;
    notifyListeners();
  }

  void organize(OrganizeMode mode) {
    _pushUndo();
    today.mode = mode;
    today.visits = organizeVisits(today.visits, today.origin, mode);
    today.reason = reasonFor(mode, today.visits, measure(today));
    impactMessage = null;
    notifyListeners();
  }

  void setEndMode(EndMode mode) {
    today.endMode = mode;
    impactMessage = switch (mode) {
      EndMode.lastClient => 'A rota termina no último cliente.',
      EndMode.company => 'A rota volta para a empresa.',
      EndMode.home => 'A rota volta para casa.',
    };
    notifyListeners();
  }

  void reorderShown(int oldIndex, int newIndex) {
    final shown = today.visits.where((visit) => visit.status != StopStatus.cancelled).toList();
    if (oldIndex < 0 || newIndex < 0 || oldIndex >= shown.length || newIndex > shown.length) return;
    if (oldIndex == newIndex) return;
    final before = measure(today).km;
    _pushUndo();
    final item = shown.removeAt(oldIndex);
    shown.insert(newIndex, item);
    item.pinIndex = null;
    final cancelled = today.visits.where((visit) => visit.status == StopStatus.cancelled).toList();
    today.visits = [...shown, ...cancelled];
    today.mode = OrganizeMode.manual;
    today.reason = 'Ordem definida manualmente.';
    impactMessage = impactText(before, measure(today).km);
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final snap = _undo.removeLast();
    final byId = {for (final visit in today.visits) visit.id: visit};
    final known = snap.ids.where(byId.containsKey).map((id) => byId[id]!).toList();
    final extras = today.visits.where((visit) => !snap.ids.contains(visit.id));
    today.visits = [...known, ...extras];
    today.mode = snap.mode;
    today.reason = snap.reason;
    impactMessage = 'Ordem anterior restaurada.';
    notifyListeners();
  }

  bool get canUndo => _undo.isNotEmpty;

  void togglePin(String id) {
    final visit = _find(id);
    final shown = today.visits.where((item) => item.status != StopStatus.cancelled).toList();
    if (visit.pinIndex == null) {
      visit.pinIndex = shown.indexWhere((item) => item.id == id);
    } else {
      visit.pinIndex = null;
    }
    notifyListeners();
  }

  void setPriority(String id, Priority priority) {
    _find(id).priority = priority;
    notifyListeners();
  }

  void setStatus(
    String id,
    StopStatus status, {
    String? note,
    String? address,
    DateTime? date,
  }) {
    final visit = _find(id);
    if (status == StopStatus.enRoute) {
      for (final other in today.visits) {
        if (other.id != id && other.status == StopStatus.enRoute) {
          other.status = StopStatus.pending;
        }
      }
    }
    visit.status = status;
    if (status == StopStatus.done) visit.completedAt = DateTime.now();
    if (note != null && note.trim().isNotEmpty) {
      final text = note.trim();
      visit.note = visit.note.isEmpty ? text : '${visit.note}. $text';
    }
    if (address != null && address.trim().isNotEmpty) {
      visit.address = address.trim();
      visit.lat = null;
      visit.lng = null;
      visit.addressUncertain = true;
    }
    if (date != null) visit.rescheduleDate = date;
    notifyListeners();
    if (address != null && address.trim().isNotEmpty) {
      geocodeMissing();
    }
  }

  String? navigatingTo;
  bool _leftForMaps = false;

  void startNavigation(String id) {
    navigatingTo = id;
    _leftForMaps = false;
  }

  void appPaused() {
    if (navigatingTo != null) _leftForMaps = true;
  }

  ({Visit visit, StopStatus previous})? finishNavigation() {
    final id = navigatingTo;
    if (id == null || !_leftForMaps) return null;
    navigatingTo = null;
    _leftForMaps = false;
    final visit = today.visits.where((item) => item.id == id).firstOrNull;
    if (visit == null || visit.status.isClosed) return null;
    return (visit: visit, previous: leaveFor(id));
  }

  StopStatus leaveFor(String id) {
    final previous = _find(id).status;
    setStatus(id, StopStatus.done);
    return previous;
  }

  void undoLeave(String id, StopStatus previous) {
    final visit = _find(id);
    visit.status = previous;
    visit.completedAt = null;
    notifyListeners();
  }

  void saveVisit({
    String? id,
    required String client,
    required String address,
    required String phone,
    required String note,
    required Priority priority,
    int? windowStartMin,
    int? windowEndMin,
    bool pinned = false,
  }) {
    if (id == null) {
      final visit = Visit(
        id: _newId(),
        client: client.trim().isEmpty ? 'Sem nome' : client.trim(),
        address: address.trim(),
        phone: phone.trim(),
        note: note.trim(),
        priority: priority,
        windowStartMin: windowStartMin,
        windowEndMin: windowEndMin,
        addressUncertain: address.trim().length < 8 || !RegExp(r'\d').hasMatch(address),
      );
      if (pinned) visit.pinIndex = today.visits.length;
      today.visits = [...today.visits, visit];
      selectedId = visit.id;
      notifyListeners();
      geocodeMissing();
      return;
    }
    final visit = _find(id);
    visit.client = client.trim().isEmpty ? 'Sem nome' : client.trim();
    final addressChanged = visit.address != address.trim();
    visit.address = address.trim();
    visit.phone = phone.trim();
    visit.note = note.trim();
    visit.priority = priority;
    visit.windowStartMin = windowStartMin;
    visit.windowEndMin = windowEndMin;
    if (pinned && visit.pinIndex == null) {
      visit.pinIndex = today.visits.indexWhere((item) => item.id == id);
    }
    if (!pinned) visit.pinIndex = null;
    if (addressChanged) {
      visit.lat = null;
      visit.lng = null;
      visit.addressUncertain = true;
    }
    notifyListeners();
    if (addressChanged) geocodeMissing();
  }

  List<Visit> addDrafts(List<DraftStop> drafts, {bool replace = false, bool geocode = true}) {
    final created = <Visit>[];
    for (final draft in drafts) {
      if (draft.invalid) continue;
      created.add(
        Visit(
          id: _newId(),
          client: draft.client,
          address: draft.address,
          phone: draft.phone,
          note: draft.note,
          lat: draft.lat,
          lng: draft.lng,
          addressUncertain: draft.lat == null || draft.addressUncertain,
          windowStartMin: draft.windowStartMin,
          windowEndMin: draft.windowEndMin,
        ),
      );
    }
    if (replace) {
      final done = today.visits.where((visit) => visit.status == StopStatus.done).toList();
      today.visits = [...done, ...created];
    } else {
      today.visits = [...today.visits, ...created];
    }
    today.closed = false;
    if (created.isNotEmpty) {
      today.reason = 'Revise os endereços e organize a sequência.';
    }
    notifyListeners();
    if (geocode) geocodeMissing();
    return created;
  }

  Future<Place?> confirmStop(String address) => _geocoder.confirmAddress(address);

  Future<void> planImported(List<DraftStop> drafts, {bool replace = false}) async {
    final kept = drafts.where((draft) => !draft.invalid).toList();
    final created = addDrafts(drafts, replace: replace, geocode: false);
    final unchecked = [
      for (var i = 0; i < created.length; i++)
        if (!created[i].hasPoint && !kept[i].notFound) created[i],
    ];
    await _locateVisits(unchecked);
    await refreshOrigin();
    final located = today.visits.any((visit) => visit.hasPoint && visit.status != StopStatus.cancelled);
    if (located) organize(OrganizeMode.curta);
  }

  void removeVisit(String id) {
    today.visits = today.visits.where((visit) => visit.id != id).toList();
    if (selectedId == id) selectedId = null;
    notifyListeners();
  }

  Future<void> useCurrentOrigin() async {
    today.origin = await _here();
    originDirty = false;
    originReady = true;
    notifyListeners();
  }

  Future<void> locateDeparture() async {
    today.origin = await locateHere(_geocoder);
    originDirty = false;
    originReady = true;
    notifyListeners();
  }

  Future<String?> currentCity() async {
    try {
      final here = await _here();
      return await _geocoder.cityAt(here.latitude, here.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<bool> refreshOrigin() async {
    try {
      await useCurrentOrigin();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setOriginAddress(String address) async {
    today.origin = await _geocoder.search(address);
    notifyListeners();
  }

  Future<void> geocodeMissing() => _locateVisits(today.visits.where((visit) => visit.notLocated).toList());

  Future<void> _locateVisits(List<Visit> visits) async {
    for (final visit in visits) {
      if (visit.address.trim().isEmpty) continue;
      try {
        final place = await _geocoder.confirmAddress(visit.address);
        if (place == null) {
          visit.addressUncertain = true;
        } else {
          visit.lat = place.latitude;
          visit.lng = place.longitude;
          visit.addressUncertain = false;
        }
      } catch (_) {
        visit.addressUncertain = true;
      }
      notifyListeners();
    }
  }

  void closeDay() {
    if (today.closed) return;
    today.closed = true;
    history = [today.clone(), ...history];
    notifyListeners();
  }

  void archiveAndStart() {
    if (today.visits.isNotEmpty) {
      final archived = today.clone()..closed = true;
      history = [archived, ...history];
    }
    final company = today.company;
    final home = today.home;
    final origin = today.origin;
    today = DayRoute(
      id: _newId(),
      date: DateTime.now(),
      origin: origin,
      company: company,
      home: home,
      visits: [],
      reason: 'Cole ou adicione as paradas.',
    );
    selectedId = null;
    impactMessage = null;
    tripStarted = false;
    showPlan = false;
    originReady = false;
    originDirty = false;
    flowError = null;
    _undo.clear();
    notifyListeners();
  }

  void duplicateRoute(DayRoute source) {
    today.visits = source.visits
        .where((visit) => visit.status != StopStatus.cancelled)
        .map((visit) {
          final copy = visit.clone(id: _newId());
          copy.status = StopStatus.pending;
          copy.completedAt = null;
          copy.rescheduleDate = null;
          return copy;
        })
        .toList();
    today.origin = source.origin;
    today.closed = false;
    today.reason = 'Rota reaproveitada. Organize a sequência antes de sair.';
    notifyListeners();
  }

  List<Visit> get frequentClients {
    final seen = <String>{};
    final result = <Visit>[];
    for (final visit in [today, ...history].expand((day) => day.visits)) {
      final key = visit.client.trim().toLowerCase();
      if (key.isEmpty || key == 'sem nome' || !seen.add(key)) continue;
      result.add(visit);
    }
    return result;
  }

  void reuseClient(Visit source) {
    final copy = source.clone(id: _newId());
    copy.status = StopStatus.pending;
    copy.completedAt = null;
    copy.rescheduleDate = null;
    today.visits = [...today.visits, copy];
    today.closed = false;
    notifyListeners();
  }

  Future<void> begin() async {
    locating = true;
    flowError = null;
    notifyListeners();
    try {
      today.origin = await _locate();
      originDirty = false;
      originReady = true;
      tripStarted = true;
      showPlan = false;
    } on GeocodeException catch (error) {
      tripStarted = true;
      originReady = false;
      flowError = error.message;
    } catch (_) {
      tripStarted = true;
      originReady = false;
      flowError = 'Não foi possível ler a localização. Edite o endereço.';
    } finally {
      locating = false;
      notifyListeners();
    }
  }

  void setOriginText(String value) {
    today.origin = Place(
      label: value.trim(),
      latitude: today.origin.latitude,
      longitude: today.origin.longitude,
    );
    originDirty = true;
    originReady = false;
    showPlan = false;
    flowError = null;
    notifyListeners();
  }

  void addStopAddress(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    today.visits = [
      ...today.visits,
      Visit(
        id: _newId(),
        client: text,
        address: text,
        addressUncertain: true,
      ),
    ];
    showPlan = false;
    flowError = null;
    notifyListeners();
  }

  Future<String?> finishPlan() async {
    final pending = today.visits.where((visit) => visit.status != StopStatus.cancelled).toList();
    if (!tripStarted) return 'Toque em iniciar para usar sua localização.';
    if (today.origin.label.trim().isEmpty) return 'Informe o endereço atual.';
    if (pending.isEmpty) return 'Adicione um endereço.';
    try {
      if (!originReady || originDirty) {
        today.origin = await _geocoder.search(today.origin.label);
        originDirty = false;
        originReady = true;
      }
      for (final visit in pending) {
        if (visit.hasPoint && !visit.addressUncertain) continue;
        final found = await _geocoder.search(visit.address);
        visit.lat = found.latitude;
        visit.lng = found.longitude;
        visit.addressUncertain = false;
      }
    } on GeocodeException catch (error) {
      flowError = error.message;
      notifyListeners();
      return error.message;
    }
    today.visits = organizeVisits(today.visits, today.origin, OrganizeMode.curta);
    today.mode = OrganizeMode.curta;
    today.reason = pending.length > 8
        ? 'Muitas paradas: a sequência segue sempre para a mais próxima.'
        : 'Sequência otimizada para reduzir deslocamento.';
    showPlan = true;
    flowError = null;
    notifyListeners();
    return null;
  }

  void _pushUndo() {
    _undo.add(_Snap(
      today.visits.map((visit) => visit.id).toList(),
      today.mode,
      today.reason,
    ));
    if (_undo.length > 20) _undo.removeAt(0);
  }

  Visit _find(String id) => today.visits.firstWhere((visit) => visit.id == id);
}

class PlannerScope extends InheritedNotifier<PlannerController> {
  const PlannerScope({
    super.key,
    required PlannerController controller,
    required super.child,
  }) : super(notifier: controller);

  static PlannerController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<PlannerScope>();
    assert(scope != null, 'PlannerScope ausente');
    return scope!.notifier!;
  }
}
