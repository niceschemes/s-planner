import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'address_scan.dart';
import 'models.dart';

class DocumentRead {
  DocumentRead({required this.fileName, required this.stops, this.error});

  final String fileName;
  final List<DraftStop> stops;
  final String? error;
}

String textFromPdfBytes(List<int> bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(document).extractText();
  } finally {
    document.dispose();
  }
}

List<DraftStop> ordersFromDocumentText(
  String raw, {
  required String fileName,
  String defaultCity = '',
}) {
  final lines = _lines(raw);
  final blocks = <_Block>[];
  final loose = <String>[];
  var block = _Block();

  void flush({String keepClient = ''}) {
    if (block.hasContent) blocks.add(block);
    block = _Block()..client = keepClient;
  }

  var index = 0;
  while (index < lines.length) {
    final line = lines[index];
    final hit = _match(line);
    if (hit == null) {
      loose.add(line);
      index++;
      continue;
    }
    var value = hit.value;
    if (value.isEmpty && index + 1 < lines.length && _match(lines[index + 1]) == null) {
      value = lines[index + 1].trim();
      index++;
    }
    if (hit.kind == _Kind.client && block.address.isNotEmpty) flush();
    if (hit.kind == _Kind.address && block.address.isNotEmpty) {
      final client = block.client;
      flush(keepClient: client);
    }
    block.set(hit.kind, value);
    index++;
  }
  if (block.hasContent) blocks.add(block);
  if (blocks.isEmpty) blocks.add(_Block());

  if (blocks.length == 1 && blocks.single.address.isEmpty) {
    for (final line in loose) {
      if (_street.hasMatch(line)) {
        blocks.single.address = line;
        break;
      }
    }
  }

  final fallback = _nameFromFile(fileName);
  final city = defaultCity.trim();
  final labeled = [
    for (final item in blocks) item.toDraft(fallbackClient: fallback, defaultCity: city),
  ];
  final scanned = scanStreetAddresses(raw, defaultCity: city);
  final labeledStreets = labeled.where((stop) => _street.hasMatch(stop.address)).length;
  final labeledBad = labeled.any((stop) => stop.address.isNotEmpty && !_street.hasMatch(stop.address));
  if (scanned.isNotEmpty && (labeledBad || labeledStreets == 0 || scanned.length > labeledStreets)) {
    return [
      for (final item in scanned)
        DraftStop(
          client: item.client,
          address: item.address,
          phone: '',
          note: item.note,
          clientUncertain: false,
          addressUncertain: false,
          duplicate: false,
          incomplete: false,
          invalid: false,
        ),
    ];
  }
  return labeled;
}

enum _Kind { address, number, district, city, cep, client, phone, order }

class _Label {
  const _Label(this.key, this.kind);

  final String key;
  final _Kind kind;
}

const _labels = <_Label>[
  _Label('endereco de entrega', _Kind.address),
  _Label('local de entrega', _Kind.address),
  _Label('razao social', _Kind.client),
  _Label('nome do cliente', _Kind.client),
  _Label('ordem de servico', _Kind.order),
  _Label('endereco', _Kind.address),
  _Label('logradouro', _Kind.address),
  _Label('destino', _Kind.address),
  _Label('numero', _Kind.number),
  _Label('bairro', _Kind.district),
  _Label('municipio', _Kind.city),
  _Label('cidade', _Kind.city),
  _Label('cliente', _Kind.client),
  _Label('destinatario', _Kind.client),
  _Label('solicitante', _Kind.client),
  _Label('telefone', _Kind.phone),
  _Label('celular', _Kind.phone),
  _Label('whatsapp', _Kind.phone),
  _Label('pedido', _Kind.order),
  _Label('fone', _Kind.phone),
  _Label('cep', _Kind.cep),
];

final _street = RegExp(
  r'\b(rua|r\.|av\.?|avenida|travessa|alameda|rodovia|praça|praca|estrada|largo)\b',
  caseSensitive: false,
);

class _Hit {
  const _Hit(this.kind, this.value);

  final _Kind kind;
  final String value;
}

class _Block {
  String client = '';
  String address = '';
  String number = '';
  String district = '';
  String city = '';
  String cep = '';
  String phone = '';
  String order = '';

  bool get hasContent =>
      client.isNotEmpty ||
      address.isNotEmpty ||
      number.isNotEmpty ||
      district.isNotEmpty ||
      city.isNotEmpty ||
      cep.isNotEmpty ||
      phone.isNotEmpty ||
      order.isNotEmpty;

  void set(_Kind kind, String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    switch (kind) {
      case _Kind.address:
        address = text;
      case _Kind.number:
        number = text;
      case _Kind.district:
        district = text;
      case _Kind.city:
        city = text;
      case _Kind.cep:
        cep = text;
      case _Kind.client:
        client = text;
      case _Kind.phone:
        phone = text;
      case _Kind.order:
        order = text;
    }
  }

  DraftStop toDraft({required String fallbackClient, required String defaultCity}) {
    var place = address.trim();
    if (number.isNotEmpty && !place.contains(number)) {
      place = place.isEmpty ? number : '$place, $number';
    }
    for (final extra in [district, city, cep]) {
      if (extra.isEmpty) continue;
      if (place.toLowerCase().contains(extra.toLowerCase())) continue;
      place = place.isEmpty ? extra : '$place, $extra';
    }
    final streetLike = _street.hasMatch(place);
    if (streetLike &&
        defaultCity.isNotEmpty &&
        city.isEmpty &&
        !place.toLowerCase().contains(defaultCity.toLowerCase()) &&
        !addressHasCity(place)) {
      place = '$place, $defaultCity';
    }

    final named = client.trim().length >= 2;
    final notes = <String>[
      if (order.isNotEmpty) 'Pedido $order',
      if (place.isEmpty) 'Endereço não encontrado no PDF',
    ];
    final incomplete = place.isEmpty || place.length < 8 || !RegExp(r'\d').hasMatch(place);
    return DraftStop(
      client: named ? client.trim() : fallbackClient,
      address: place,
      phone: phone.trim(),
      note: notes.join('. '),
      clientUncertain: !named,
      addressUncertain: incomplete,
      duplicate: false,
      incomplete: incomplete,
      invalid: false,
    );
  }
}

const _breaks = [
  r'endere[cç]o(?:\s+de\s+entrega)?',
  r'local\s+de\s+entrega',
  r'raz[aã]o\s+social',
  r'nome\s+do\s+cliente',
  r'ordem\s+de\s+servi[cç]o',
  r'logradouro',
  r'destino',
  r'n[uú]mero',
  r'bairro',
  r'munic[ií]pio',
  r'cidade',
  r'cliente',
  r'destinat[aá]rio',
  r'solicitante',
  r'telefone',
  r'celular',
  r'whatsapp',
  r'pedido',
  r'fone',
  r'cep',
];

List<String> _lines(String raw) {
  var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  text = text.replaceAll(RegExp('\\s+(?=(?:${_breaks.join('|')})\\b)', caseSensitive: false), '\n');
  return text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

_Hit? _match(String line) {
  final folded = _fold(line);
  final order = RegExp(r'^os\s*[:\-]\s*(.*)$', caseSensitive: false).firstMatch(line);
  if (order != null) return _Hit(_Kind.order, order.group(1)!.trim());

  for (final label in _labels) {
    if (folded == label.key) return _Hit(label.kind, '');
    final prefix = '${label.key} ';
    final colon = '${label.key}:';
    final dash = '${label.key}-';
    if (folded.startsWith(prefix) || folded.startsWith(colon) || folded.startsWith(dash)) {
      final value = line.substring(label.key.length).replaceFirst(RegExp(r'^[\s:\-]+'), '').trim();
      return _Hit(label.kind, value);
    }
  }
  return null;
}

String _fold(String value) {
  return value
      .toLowerCase()
      .replaceAll('ç', 'c')
      .replaceAll('ã', 'a')
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u');
}

String _nameFromFile(String fileName) {
  final base = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  final cleaned = base.replaceAll(RegExp(r'[-_]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return cleaned.isEmpty ? 'Sem nome' : cleaned;
}
