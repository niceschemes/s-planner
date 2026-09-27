class ScannedAddress {
  const ScannedAddress({required this.client, required this.address, this.note = ''});

  final String client;
  final String address;
  final String note;
}

const _states = 'AC|AL|AP|AM|BA|CE|DF|ES|GO|MA|MT|MS|MG|PA|PB|PR|PE|PI|RJ|RN|RS|RO|RR|SC|SP|SE|TO';

final _stateMark = RegExp('(?<=^|[\\s,/|-])($_states)(?=\$|[\\s,.;/|)-])');

final _stateAfter = RegExp('^\\s*[-/,]?\\s*($_states)(?=\$|[\\s,.;/|)-])');

final _stateOnly = RegExp('^($_states)\$');

final _cep = RegExp(r'^\d{5}-?\d{3}$');

final _houseNumber = RegExp(
  r'(?<!\d)(?:n[uú]mero\s+)?(\d{1,4}|s/n)\b(?!\d)(?!\s*h\b)',
  caseSensitive: false,
);

final _hood = RegExp(
  r'\b(centro|cidade\s+nova|jardim\s+[A-Za-zÀ-ú]+(?:\s+[A-Za-zÀ-ú]+){0,2}|vila\s+[A-Za-zÀ-ú]+|parque\s+[A-Za-zÀ-ú]+(?:\s+[A-Za-zÀ-ú]+)?|vista\s+da\s+colina|benedito\s+[A-Za-zÀ-ú]+(?:\s+[A-Za-zÀ-ú]+\.?)?)',
  caseSensitive: false,
);

final _particle = RegExp(r'^(de|da|do|dos|das|e)$', caseSensitive: false);

final _nameToken = RegExp(r"^[A-Za-zÀ-ú0-9][A-Za-zÀ-ú0-9'.]{0,}$");

const _ban = {
  'quebrada',
  'partes',
  'simular',
  'anotacoes',
  'soltas',
  'rodape',
  'baguncado',
  'tambem',
  'palavra',
  'ficticios',
  'endereco',
  'observacao',
  'pagina',
  'arquivo',
  'sintetico',
  'horario',
  'protocolo',
  'apareceu',
  'citou',
  'menciona',
  'aponta',
  'solto',
  'teste',
  'upa',
  'fichas',
};

final _skipToken = {
  'rua',
  'avenida',
  'travessa',
  'alameda',
  'rodovia',
  'praca',
  'estrada',
  'largo',
  'centro',
  'jardim',
  'vila',
  'brasil',
};

class _Anchor {
  const _Anchor(this.start, this.city, this.state);

  final int start;
  final String city;
  final String state;
}

List<ScannedAddress> scanStreetAddresses(String raw, {String defaultCity = ''}) {
  final text = _prepare(raw);
  if (text.isEmpty) return const [];
  final city = defaultCity.trim();
  final anchors = <_Anchor>[
    for (final start in _cityStarts(text, city))
      _Anchor(start, city, _stateAfter.firstMatch(text.substring(start + city.length))?.group(1) ?? ''),
    for (final mark in _stateMark.allMatches(text)) _Anchor(mark.start, '', mark.group(1)!),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final found = <ScannedAddress>[];
  final seen = <String>{};
  for (final anchor in anchors) {
    final from = anchor.start - 120 < 0 ? 0 : anchor.start - 120;
    final window = text.substring(from, anchor.start);
    if (RegExp(r'UPA\s*/\s*$', caseSensitive: false).hasMatch(window.trimRight())) continue;
    final parsed = _fromWindow(window, city: anchor.city, fallbackCity: city, state: anchor.state);
    if (parsed == null) continue;
    final key = _fold(parsed.client);
    if (!seen.add(key)) continue;
    found.add(parsed);
  }
  return found;
}

Iterable<int> _cityStarts(String text, String city) sync* {
  if (city.length < 3) return;
  final folded = _fold(text);
  final target = _fold(city);
  var index = folded.indexOf(target);
  while (index >= 0) {
    final glued = index > 0 && RegExp(r'[a-zà-ú]').hasMatch(folded[index - 1]);
    final camel = glued && RegExp(r'[A-ZÀ-Ú]').hasMatch(text[index]);
    final end = index + target.length;
    final open = end >= folded.length || !RegExp(r'[a-z]').hasMatch(folded[end]);
    if ((!glued || camel) && open) yield index;
    index = folded.indexOf(target, index + 1);
  }
}

String _prepare(String raw) {
  var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAllMapped(RegExp(r'([A-Za-zÀ-ú])(\d)'), (match) => '${match[1]} ${match[2]}');
  text = text.replaceAllMapped(RegExp(r'(\d)([A-Za-zÀ-ú])'), (match) => '${match[1]} ${match[2]}');
  return text;
}

ScannedAddress? _fromWindow(
  String window, {
  required String city,
  required String fallbackCity,
  required String state,
}) {
  final numbers = _houseNumber.allMatches(window).toList();
  if (numbers.isEmpty) return null;
  final number = numbers.last;
  final value = number.group(1)!;
  final before = window.substring(0, number.start);
  final street = _streetName(before);
  if (street == null) return null;
  var after = window.substring(number.end);
  var hood = '';
  final hoodMatch = _hood.firstMatch(after);
  if (hoodMatch != null) {
    hood = hoodMatch.group(1)!.replaceAll(RegExp(r'\s+'), ' ').trim();
    after = after.replaceRange(hoodMatch.start, hoodMatch.end, ' ');
  }
  final pieces = after
      .split(RegExp(r'[,|/]|\s-\s|-(?=\s*$)|^\s*-'))
      .map((piece) => piece.replaceAll(RegExp(r'^[^A-Za-zÀ-ú]+|[^A-Za-zÀ-ú]+$'), '').trim())
      .where((piece) => piece.isNotEmpty)
      .toList();
  var place = city;
  if (place.isEmpty && pieces.isNotEmpty) {
    place = _tidyCity(pieces.removeLast());
    if (hood.isEmpty && pieces.isNotEmpty) hood = pieces.join(' ');
  }
  final hoodWords = hood.split(' ');
  if (place.isEmpty && state.isNotEmpty && hoodWords.length >= 3) {
    place = _tidyCity(hoodWords.removeLast());
    hood = hoodWords.join(' ');
  }
  if (place.isEmpty) place = fallbackCity;
  final type = street.$1;
  final name = street.$2;
  final parts = [
    '$type $name',
    value,
    if (hood.isNotEmpty) hood,
    if (place.isNotEmpty) place,
    if (state.isNotEmpty) state,
  ];
  return ScannedAddress(client: '$type $name, $value', address: parts.join(', '));
}

String _tidyCity(String value) {
  final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text != text.toUpperCase()) return text;
  return text
      .toLowerCase()
      .split(' ')
      .map((word) => _particle.hasMatch(word) || word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String? addressCity(String address) {
  final parts = address
      .replaceAll(RegExp(r'\s-\s'), ',')
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) return null;
  var streetEnd = 1;
  if (RegExp(r'^(\d{1,5}|s/n)$', caseSensitive: false).hasMatch(parts[1])) streetEnd = 2;
  final rest = [
    for (final part in parts.skip(streetEnd))
      if (!_cep.hasMatch(part) && !_stateOnly.hasMatch(part) && _fold(part) != 'brasil')
        part.replaceFirst(RegExp('\\s*[-/]?\\s*($_states)\$'), '').trim(),
  ].where((part) => RegExp(r'[A-Za-zÀ-ú]{3}').hasMatch(part)).toList();
  if (rest.isEmpty) return null;
  return rest.last;
}

String? addressState(String address) {
  final match = RegExp('(?:^|[\\s,/-])($_states)\\s*(?:,\\s*brasil)?\\s*\$', caseSensitive: false)
      .firstMatch(address.trim());
  final value = match?.group(1);
  return value == null || value != value.toUpperCase() ? null : value;
}

bool addressHasCity(String address) {
  final text = address.replaceAll(RegExp(r'\b\d{5}-?\d{3}\b'), ' ');
  final number = _houseNumber.allMatches(text).toList();
  if (number.isEmpty) return addressCity(text) != null;
  final tail = text.substring(number.last.end);
  return RegExp(r'[A-Za-zÀ-ú]{3}').hasMatch(tail);
}

(String, String)? _streetName(String before) {
  final tokens = before
      .split(RegExp(r'\s+'))
      .map((token) => token.replaceAll(RegExp(r"^[,:;\-/'“”]+|[,:;\-/'“”]+$"), ''))
      .where((token) => token.isNotEmpty)
      .toList();
  final name = <String>[];
  for (var i = tokens.length - 1; i >= 0 && name.length < 7; i--) {
    final token = tokens[i];
    final folded = _fold(token);
    if (_ban.contains(folded)) break;
    if (!_particle.hasMatch(token) && !RegExp(r'^[A-ZÁ-Ú0-9]').hasMatch(token)) break;
    if (name.isNotEmpty && (folded == 'rua' || folded == 'r' || folded == 'av' || folded == 'avenida' || folded == 'alameda')) {
      name.insert(0, token);
      break;
    }
    if (_particle.hasMatch(token)) {
      if (name.isNotEmpty) name.insert(0, token);
      continue;
    }
    if (!_nameToken.hasMatch(token)) break;
    if (token.length == 1 && !RegExp(r'^[A-Z0-9]$').hasMatch(token)) break;
    name.insert(0, token);
  }
  while (name.isNotEmpty && _particle.hasMatch(name.first)) {
    name.removeAt(0);
  }
  if (name.isEmpty) return null;
  var type = 'Rua';
  final head = _fold(name.first).replaceAll('.', '');
  if (head == 'rua' || head == 'r') {
    type = 'Rua';
    name.removeAt(0);
  } else if (head == 'av' || head == 'avenida') {
    type = head == 'av' ? 'Av' : 'Avenida';
    name.removeAt(0);
  } else if (head == 'dr') {
    name.removeAt(0);
  } else if (head == 'praca') {
    type = 'Praça';
    name.removeAt(0);
  }
  if (name.isEmpty) return null;
  if (name.length == 1 && _fold(name.single).length < 4 && !RegExp(r'\d').hasMatch(name.single)) return null;
  if (name.any((token) => _ban.contains(_fold(token)))) return null;
  return (type, name.join(' '));
}

List<String> geocodeQueries(String address) {
  final cleaned = address.replaceAll(RegExp(r'\s+'), ' ').trim();
  final queries = <String>[];
  void add(String value) {
    final text = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length < 8) return;
    if (queries.any((item) => item.toLowerCase() == text.toLowerCase())) return;
    queries.add(text);
  }

  add(cleaned);
  final city = addressCity(cleaned);
  final state = addressState(cleaned);
  final street = RegExp(r'^(.*?(?:\d+|s/n))', caseSensitive: false).firstMatch(cleaned);
  if (street != null && city != null) {
    add('${street.group(1)}, $city${state == null ? '' : ', $state'}, Brasil');
    add('${street.group(1)}, $city');
  }
  add('$cleaned, Brasil');
  return queries.take(4).toList();
}

bool geocodeHitMatches(String address, String displayName) {
  final foldedName = _fold(displayName);
  final city = addressCity(address);
  final cityTokens = city == null ? const <String>{} : _fold(city).split(RegExp(r'[^a-z0-9]+')).toSet();
  final tokens = _fold(address)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 4 && !_skipToken.contains(token) && !cityTokens.contains(token))
      .toList();
  if (tokens.isEmpty || !tokens.any(foldedName.contains)) return false;
  if (city != null && !foldedName.contains(_fold(city))) return false;
  return true;
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
