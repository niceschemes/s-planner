import 'place.dart';

enum StopStatus {
  pending,
  enRoute,
  arrived,
  inService,
  done,
  absent,
  badAddress,
  reschedule,
  cancelled,
}

enum Priority { high, medium, low }

enum OrganizeMode { rapida, curta, prioridade, horarios, manual }

enum EndMode { lastClient, company, home }

enum HistoryFilter { all, done, absent, reschedule, cancelled }

extension StopStatusLabel on StopStatus {
  String get label => switch (this) {
        StopStatus.pending => 'Pendente',
        StopStatus.enRoute => 'A caminho',
        StopStatus.arrived => 'Cheguei',
        StopStatus.inService => 'Em atendimento',
        StopStatus.done => 'Concluído',
        StopStatus.absent => 'Cliente ausente',
        StopStatus.badAddress => 'Endereço incorreto',
        StopStatus.reschedule => 'Remarcar',
        StopStatus.cancelled => 'Cancelado',
      };

  bool get isClosed => this == StopStatus.done || this == StopStatus.cancelled;
}

extension PriorityLabel on Priority {
  String get label => switch (this) {
        Priority.high => 'Alta',
        Priority.medium => 'Média',
        Priority.low => 'Baixa',
      };
}

extension OrganizeModeLabel on OrganizeMode {
  String get label => switch (this) {
        OrganizeMode.rapida => 'Rápida',
        OrganizeMode.curta => 'Curta',
        OrganizeMode.prioridade => 'Prioridade',
        OrganizeMode.horarios => 'Horários',
        OrganizeMode.manual => 'Manual',
      };
}

extension EndModeLabel on EndMode {
  String get label => switch (this) {
        EndMode.lastClient => 'Último cliente',
        EndMode.company => 'Empresa',
        EndMode.home => 'Casa',
      };
}

class Visit {
  Visit({
    required this.id,
    required this.client,
    required this.address,
    this.phone = '',
    this.note = '',
    this.lat,
    this.lng,
    this.status = StopStatus.pending,
    this.priority = Priority.medium,
    this.windowStartMin,
    this.windowEndMin,
    this.pinIndex,
    this.completedAt,
    this.rescheduleDate,
    this.addressUncertain = false,
    this.area = '',
  });

  final String id;
  String client;
  String address;
  String phone;
  String note;
  double? lat;
  double? lng;
  StopStatus status;
  Priority priority;
  int? windowStartMin;
  int? windowEndMin;
  int? pinIndex;
  DateTime? completedAt;
  DateTime? rescheduleDate;
  bool addressUncertain;
  String area;

  bool get hasPoint => lat != null && lng != null;

  bool get notLocated => !hasPoint && address.trim().isNotEmpty;

  bool get hasWindow => windowStartMin != null || windowEndMin != null;

  Place asPlace() {
    return Place(label: id, latitude: lat!, longitude: lng!);
  }

  Visit clone({String? id}) {
    return Visit(
      id: id ?? this.id,
      client: client,
      address: address,
      phone: phone,
      note: note,
      lat: lat,
      lng: lng,
      status: status,
      priority: priority,
      windowStartMin: windowStartMin,
      windowEndMin: windowEndMin,
      pinIndex: pinIndex,
      completedAt: completedAt,
      rescheduleDate: rescheduleDate,
      addressUncertain: addressUncertain,
      area: area,
    );
  }
}

class DayRoute {
  DayRoute({
    required this.id,
    required this.date,
    required this.origin,
    required this.company,
    required this.home,
    required this.visits,
    this.endMode = EndMode.lastClient,
    this.mode = OrganizeMode.curta,
    this.closed = false,
    this.startMin = 8 * 60,
    this.reason = 'Sequência otimizada para reduzir deslocamento.',
  });

  final String id;
  DateTime date;
  Place origin;
  Place company;
  Place home;
  List<Visit> visits;
  EndMode endMode;
  OrganizeMode mode;
  bool closed;
  int startMin;
  String reason;

  int get openCount =>
      visits.where((visit) => visit.status != StopStatus.cancelled).length;

  int countOf(StopStatus status) =>
      visits.where((visit) => visit.status == status).length;

  DayRoute clone() {
    return DayRoute(
      id: id,
      date: date,
      origin: origin,
      company: company,
      home: home,
      visits: visits.map((visit) => visit.clone()).toList(),
      endMode: endMode,
      mode: mode,
      closed: closed,
      startMin: startMin,
      reason: reason,
    );
  }
}

class DraftStop {
  DraftStop({
    required this.client,
    required this.address,
    required this.phone,
    required this.note,
    required this.clientUncertain,
    required this.addressUncertain,
    required this.duplicate,
    required this.incomplete,
    required this.invalid,
    this.windowStartMin,
    this.windowEndMin,
    this.lat,
    this.lng,
    this.notFound = false,
  });

  String client;
  String address;
  String phone;
  String note;
  bool clientUncertain;
  bool addressUncertain;
  bool duplicate;
  bool incomplete;
  bool invalid;
  bool notFound;
  int? windowStartMin;
  int? windowEndMin;
  double? lat;
  double? lng;
}
