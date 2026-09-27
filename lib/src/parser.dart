import 'address_scan.dart';
import 'models.dart';

final _phonePattern = RegExp(r'(?:\(?\d{2}\)?[\s-]*)?\d{4,5}-\d{4}');
final _streetPattern = RegExp(
  r'\b(rua|r\.|av\.?|avenida|travessa|alameda|rodovia|praça|praca|estrada|largo)\b',
  caseSensitive: false,
);
final _notePattern = RegExp(
  r'\b(ligar|boleto|assinatura|retirar|atende|urgente|levar|cobrar|antes)\b',
  caseSensitive: false,
);
final _untilPattern = RegExp(r'at[eé]\s*(\d{1,2})\s*h', caseSensitive: false);
final _rangePattern = RegExp(
  r'(\d{1,2})(?::(\d{2}))?\s*[hH]?\s*-\s*(\d{1,2})(?::(\d{2}))?\s*[hH]?',
);

List<DraftStop> parseStops(String raw, {String defaultCity = ''}) {
  final city = defaultCity.trim();
  final drafts = raw
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => _parseLine(line, city))
      .toList();
  flagDuplicateDrafts(drafts);
  return drafts;
}

DraftStop _parseLine(String line, String city) {
  final phoneMatch = _phonePattern.firstMatch(line);
  final phone = phoneMatch?.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  var rest = line;
  if (phoneMatch != null) {
    rest = rest.replaceFirst(phoneMatch.group(0)!, ' ');
  }
  rest = rest.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

  final parts = _parts(rest)
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty && part != '-' && part != '|')
      .toList();

  var client = '';
  var address = '';
  var note = '';
  int? windowStart;
  int? windowEnd;

  final until = _untilPattern.firstMatch(line);
  if (until != null) {
    windowEnd = int.parse(until.group(1)!) * 60;
  }
  if (line.contains(':') || line.toLowerCase().contains('h')) {
    final range = _rangePattern.firstMatch(line);
    if (range != null) {
      windowStart = int.parse(range.group(1)!) * 60 + int.parse(range.group(2) ?? '0');
      windowEnd = int.parse(range.group(3)!) * 60 + int.parse(range.group(4) ?? '0');
    }
  }

  for (final part in parts) {
    if (_isNote(part)) {
      note = note.isEmpty ? part : '$note. $part';
      continue;
    }
    if (address.isEmpty && _isAddress(part)) {
      address = part;
      continue;
    }
    if (client.isEmpty) {
      client = part;
      continue;
    }
    if (address.isEmpty) {
      address = part;
      continue;
    }
    note = note.isEmpty ? part : '$note. $part';
  }

  final hadClient = client.trim().length >= 2;
  if (!hadClient) client = 'Sem nome';

  if (city.isNotEmpty &&
      address.isNotEmpty &&
      !address.toLowerCase().contains(city.toLowerCase()) &&
      !addressHasCity(address)) {
    address = '$address, $city';
  }

  final incomplete = address.isEmpty || address.length < 8 || !RegExp(r'\d').hasMatch(address);

  return DraftStop(
    client: client,
    address: address,
    phone: phone,
    note: note,
    clientUncertain: !hadClient,
    addressUncertain: incomplete,
    duplicate: false,
    incomplete: incomplete,
    invalid: !hadClient && address.isEmpty && phone.isEmpty && note.isEmpty,
    windowStartMin: windowStart,
    windowEndMin: windowEnd,
  );
}

List<String> _parts(String rest) {
  if (rest.contains('|')) return rest.split('|');
  if (rest.contains(' - ')) return rest.split(' - ');
  if (rest.contains(',')) return rest.split(',');
  return [rest];
}

bool _isAddress(String value) => _streetPattern.hasMatch(value);

bool _isNote(String value) => _notePattern.hasMatch(value) && !_isAddress(value);

void flagDuplicateDrafts(List<DraftStop> drafts) {
  final seenAddress = <String>{};
  final seenPhone = <String>{};
  for (final draft in drafts) {
    final address = _normalize(draft.address);
    final phone = draft.phone.replaceAll(RegExp(r'\D'), '');
    final repeatedAddress = address.length > 8 && !seenAddress.add(address);
    final repeatedPhone = phone.length >= 8 && !seenPhone.add(phone);
    draft.duplicate = repeatedAddress || repeatedPhone;
  }
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[.,]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
