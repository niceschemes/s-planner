import 'dart:ui';

import 'package:curso/src/pdf_orders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  test('lê cliente, endereço, bairro, cep e telefone', () {
    const raw = '''
PEDIDO 1042
Cliente: Oficina Ramos
Endereço: Av. Brasil, 900
Bairro: Jardim
Cidade: São João da Boa Vista
CEP: 13870-000
Telefone: (19) 99720-4411
''';
    final stop = ordersFromDocumentText(raw, fileName: 'pedido-1042.pdf').single;
    expect(stop.client, 'Oficina Ramos');
    expect(stop.address, 'Av. Brasil, 900, Jardim, São João da Boa Vista, 13870-000');
    expect(stop.phone, '(19) 99720-4411');
    expect(stop.note, 'Pedido 1042');
    expect(stop.incomplete, isFalse);
  });

  test('junta número que está na linha de baixo', () {
    const raw = '''
Cliente
Ana Souza
Endereço
Rua das Flores
Número
120
''';
    final stop = ordersFromDocumentText(raw, fileName: 'ana.pdf').single;
    expect(stop.client, 'Ana Souza');
    expect(stop.address, 'Rua das Flores, 120');
    expect(stop.incomplete, isFalse);
  });

  test('separa dois pedidos no mesmo texto', () {
    const raw = '''
Cliente: Ana
Endereço: Rua das Flores, 120
Cliente: Marcos
Endereço: Av. Brasil, 10
''';
    final stops = ordersFromDocumentText(raw, fileName: 'lote.pdf');
    expect(stops.map((stop) => stop.client), ['Ana', 'Marcos']);
    expect(stops.map((stop) => stop.address), ['Rua das Flores, 120', 'Av. Brasil, 10']);
  });

  test('usa o nome do arquivo quando o endereço não aparece', () {
    final stop = ordersFromDocumentText('Pedido: 9\nObservação: retirar peça', fileName: 'retirada-centro.pdf').single;
    expect(stop.client, 'retirada centro');
    expect(stop.address, isEmpty);
    expect(stop.incomplete, isTrue);
    expect(stop.note, contains('Endereço não encontrado'));
    expect(stop.clientUncertain, isTrue);
  });

  test('acha a rua mesmo sem o rótulo endereço', () {
    const raw = '''
Entrega para o João
Rua Central, 87
ligar antes
''';
    final stop = ordersFromDocumentText(raw, fileName: 'joao.pdf', defaultCity: 'São João da Boa Vista').single;
    expect(stop.address, 'Rua Central, 87, São João da Boa Vista');
  });

  test('lê o endereço de um PDF gerado', () {
    final document = PdfDocument();
    document.pages.add().graphics.drawString(
      'Cliente: Oficina Ramos\nEndereco: Av. Brasil, 900\nCidade: Sao Joao',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
      bounds: const Rect.fromLTWH(40, 40, 400, 120),
    );
    final bytes = document.saveSync();
    document.dispose();

    final stop = ordersFromDocumentText(textFromPdfBytes(bytes), fileName: 'ramos.pdf').single;
    expect(stop.client, 'Oficina Ramos');
    expect(stop.address, contains('Av. Brasil, 900'));
  });

  test('lê as ruas de um PDF solto e ignora frase que não é endereço', () {
    const raw = '''
ROMANEIO DE DOCES - ENTREGAS DO DIA
Dados ficticios para testar leitura de pedido + endereco.
Cliente pediu para ligar antes de sair
RUA XV DE NOVEMBRO, 447 - CENTRO - AGUAI SP
perto da padaria / numero pode estar borrado
RUA 7 DE SETEMBRO, 256 - CENTRO - AGUAI SP
esquina com Major Braga / rua tambem aparece como Sete de Setembro
RUA CARLOS GOMES, 606 - CENTRO - AGUAI SP
RUA VALINS 746 CENTRO AGUAI - SP | recado: bolo pode amassar
RUA JOAQUIM JOSE 187 CENTRO AGUAI SP / entregar na mao, nao deixar na portaria
RUA OSORIO BARBOSA S/N JARDIM CENTER CITY AGUAI-SP // comentario solto
RUA MIGUEL ANGELO 791 VILA BRAGA AGUAI SP - observacao escrita torta: portao azul
''';
    final stops = ordersFromDocumentText(raw, fileName: 'entregas-aguai.pdf', defaultCity: 'Aguaí');
    final addresses = stops.map((stop) => stop.address.toLowerCase()).toList();
    expect(addresses, [
      contains('xv de novembro'),
      contains('7 de setembro'),
      contains('carlos gomes'),
      contains('valins'),
      contains('joaquim jose'),
      contains('osorio barbosa'),
      contains('miguel angelo'),
    ]);
    expect(stops.every((stop) => stop.address.contains('Aguaí')), isTrue);
    expect(addresses.where((item) => item.contains('solto')).join(' | '), isEmpty);
    expect(stops.any((stop) => stop.address.contains('São João')), isFalse);
    expect(stops.any((stop) => stop.address.toLowerCase().contains('quebrada')), isFalse);
  });

  test('tira o endereço escondido na frase e ignora o comentário', () {
    const raw = '''
ROMANEIO DE DOCES - ENTREGAS DO DIA
a familia citou XV de Novembro 447, Centro, AguaI, mas no papel veio dividido.
rua tambem aparece como R. 7 de Setembro
Registro: Sete de Setembro, numero 256, Centro - AguaI SP, talvez entrada lateral.
Carlos Gomes 606 Centro AguaI, sem CEP no bilhete.
rua quebrada em duas partes para simular OCR ruim
Jose Coimbra 165 apareceu sem 'Rua'
Rascunho aponta Jose Coimbra 165 Vila Braga AguaI-SP, sem campo nomeado.
texto livre sem separador: Almirante Tamandare552CentroAguaI
Rodape lateral: Rua Francisco Mattar 333 Jardim Novaguai AguaI SP.
No canto: Av Olinda Silveira Cruz Braga 215 Parque Interlagos AguaI, talvez endereco de apoio.
Av Olinda Silveira Cruz Braga 215 apareceu no meio da observacao
Tancredo Neves 23 Centro AguaI SP, sem indicar se e praca ou rua.
''';
    final stops = ordersFromDocumentText(raw, fileName: 'entregas-aguai.pdf', defaultCity: 'Aguaí');
    final addresses = stops.map((stop) => stop.address.toLowerCase()).toList();
    expect(addresses.any((item) => item.contains('xv de novembro') && item.contains('447')), isTrue);
    expect(addresses.any((item) => item.contains('sete de setembro') && item.contains('256')), isTrue);
    expect(addresses.any((item) => item.contains('carlos gomes') && item.contains('606')), isTrue);
    expect(addresses.any((item) => item.contains('jose coimbra') && item.contains('165')), isTrue);
    expect(addresses.any((item) => item.contains('tamandare') && item.contains('552')), isTrue);
    expect(addresses.any((item) => item.contains('francisco mattar') && item.contains('333')), isTrue);
    expect(addresses.any((item) => item.contains('olinda silveira') && item.contains('215')), isTrue);
    expect(addresses.any((item) => item.contains('tancredo neves') && item.contains('23')), isTrue);
    expect(addresses.any((item) => item.contains('quebrada') || item.contains('anotacoes') || item.contains('apareceu')), isFalse);
    expect(addresses.where((item) => item.contains('olinda silveira')).length, 1);
    expect(stops.every((stop) => stop.address.contains('Aguaí')), isTrue);
  });

  test('lê endereços de qualquer cidade, sem depender de Aguaí', () {
    const raw = '''
LISTA DE VISITAS
RUA AUGUSTA 1500 - CONSOLACAO - SAO PAULO SP
Av. Afonso Pena, 1000, Centro, Belo Horizonte - MG
RUA DAS PALMEIRAS 45 JARDIM AMERICA CAMPINAS/SP
''';
    final stops = ordersFromDocumentText(raw, fileName: 'visitas.pdf', defaultCity: 'Aguaí');
    final addresses = stops.map((stop) => stop.address).toList();
    expect(addresses, hasLength(3));
    final lower = addresses.map((item) => item.toLowerCase()).toList();
    expect(lower[0], allOf(contains('augusta'), contains('1500'), contains('sao paulo')));
    expect(addresses[0], endsWith(', SP'));
    expect(lower[1], allOf(contains('afonso pena'), contains('1000'), contains('belo horizonte')));
    expect(addresses[1], endsWith(', MG'));
    expect(lower[2], allOf(contains('palmeiras'), contains('45'), contains('campinas')));
    expect(addresses.any((item) => item.contains('Aguaí')), isFalse);
  });

  test('não coloca a cidade padrão em cima de outra cidade escrita', () {
    const raw = 'Cliente: Loja Centro\nEndereço: Rua Augusta, 1500, São Paulo';
    final stop = ordersFromDocumentText(raw, fileName: 'loja.pdf', defaultCity: 'Aguaí').single;
    expect(stop.address, 'Rua Augusta, 1500, São Paulo');
  });

  test('lê um texto corrido do PDF', () {
    const raw = 'Cliente: Maria Endereço: Av. Brasil, 900 Bairro: Centro';
    final stop = ordersFromDocumentText(raw, fileName: 'maria.pdf').single;
    expect(stop.client, 'Maria');
    expect(stop.address, 'Av. Brasil, 900, Centro');
  });
}
