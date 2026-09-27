import 'dart:convert';

import 'package:curso/src/geocode_cache.dart';
import 'package:curso/src/geocoder.dart';
import 'package:curso/src/links.dart';
import 'package:curso/src/models.dart';
import 'package:curso/src/place.dart';
import 'package:curso/src/road_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('a busca no mapa tenta de novo e recusa cidade errada', () async {
    final client = _ScriptClient([
      '[]',
      '[{"lat":"-21.97","lon":"-46.79","display_name":"Rua Qualquer, São João da Boa Vista, Brasil"}]',
      '[{"lat":"-22.058","lon":"-46.978","display_name":"Rua XV de Novembro, Aguaí, São Paulo, Brasil"}]',
    ]);
    final geocoder = Geocoder(client: client, cache: MemoryGeocodeCache(), gap: Duration.zero);
    final place = await geocoder.confirmAddress('Rua XV de Novembro, 447, Centro, Aguaí, SP');
    expect(place, isNotNull);
    expect(place!.latitude, closeTo(-22.058, 0.001));
    expect(await geocoder.confirmAddress('solto, pode estar, São João da Boa Vista'), isNull);
  });

  test('a conferência no mapa vale para qualquer cidade', () async {
    final client = _ScriptClient([
      '[{"lat":"-19.93","lon":"-43.93","display_name":"Avenida Afonso Pena, Centro, Belo Horizonte, Minas Gerais, Brasil"}]',
      '[{"lat":"-23.55","lon":"-46.66","display_name":"Rua Augusta, Consolação, São Paulo, Brasil"}]',
    ]);
    final geocoder = Geocoder(client: client, cache: MemoryGeocodeCache(), gap: Duration.zero);
    final bh = await geocoder.confirmAddress('Av Afonso Pena, 1000, Centro, Belo Horizonte, MG');
    expect(bh!.latitude, closeTo(-19.93, 0.001));
    expect(await geocoder.confirmAddress('Rua Augusta, 1500, Campinas'), isNull);
  });

  test('o cache evita uma segunda busca no Nominatim', () async {
    final client = _CountClient();
    final geocoder = Geocoder(
      client: client,
      cache: MemoryGeocodeCache(),
      gap: Duration.zero,
    );

    final first = await geocoder.search('Rua das Flores, 120');
    final second = await geocoder.search('  rua das flores, 120  ');

    expect(client.calls, 1);
    expect(second.latitude, first.latitude);
    expect(second.longitude, first.longitude);
  });

  test('a resposta do OSRM vira a linha da rota', () {
    const body = '''
{"code":"Ok","routes":[{"geometry":{"type":"LineString","coordinates":[[-46.8,-21.97],[-46.7,-21.95]]}}]}
''';
    final points = parseOsrmRoute(body);
    expect(points, isNotNull);
    expect(points!.first.latitude, -21.97);
    expect(points.first.longitude, -46.8);
    expect(points.last.latitude, -21.95);
  });

  test('resposta inválida do OSRM não inventa uma rota', () {
    expect(parseOsrmRoute('{"code":"NoRoute"}'), isNull);
    expect(parseOsrmRoute('não é json'), isNull);
  });

  test(
    'o link da rota completa usa coordenadas e limita os pontos intermediários',
    () {
      final stops = [
        for (var i = 0; i < 12; i++)
          (lat: -21.0 - i / 100.0, lng: -46.0 - i / 100.0),
      ];
      final link = mapsRouteLink(
        originLat: -21.97,
        originLng: -46.80,
        stops: stops,
      );

      expect(link, startsWith('https://www.google.com/maps/dir/?api=1'));
      expect(link, contains('origin=-21.97,-46.8'));
      expect(link, contains('travelmode=driving'));
      expect(link, contains('destination=-21.11,-46.11'));
      expect(link, isNot(contains('key=')));
      expect('|'.allMatches(link!).length, 8);
    },
  );

  test('a rota do dia abre no Maps a partir das paradas que já têm ponto', () {
    final link = mapsRouteFor(
      origin: const Place(label: 'Centro', latitude: -21.97, longitude: -46.80),
      visits: [
        Visit(
          id: 'a',
          client: 'Ana',
          address: 'Rua A',
          lat: -21.96,
          lng: -46.79,
        ),
        Visit(id: 'b', client: 'Sem ponto', address: 'Rua B'),
        Visit(
          id: 'c',
          client: 'Marcos',
          address: 'Rua C',
          lat: -21.90,
          lng: -46.70,
        ),
      ],
    );

    expect(link, contains('destination=-21.9,-46.7'));
    expect(link, contains('waypoints=-21.96,-46.79'));
    expect(
      mapsForVisit(
        Visit(id: 'a', client: 'Ana', address: 'Rua A', lat: -21.1, lng: -46.2),
      ),
      allOf(contains('destination=-21.1,-46.2'), contains('dir_action=navigate')),
    );
    expect(
      wazeForVisit(Visit(id: 'b', client: 'Ana', address: 'Rua A')),
      contains('waze.com/ul?q='),
    );
  });
}

class _ScriptClient extends http.BaseClient {
  _ScriptClient(this.bodies);

  final List<String> bodies;
  int index = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = index < bodies.length ? bodies[index] : '[]';
    index++;
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200, request: request);
  }
}

class _CountClient extends http.BaseClient {
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    final bytes = utf8.encode('[{"lat":"-21.97","lon":"-46.80"}]');
    return http.StreamedResponse(Stream.value(bytes), 200, request: request);
  }
}
