import 'package:curso/src/parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const raw = '''
João - Rua das Flores, 120 - ligar antes
Maria | Av Brasil 900 | 1199999-9999 | boleto
Carlos, Rua X 44, atende até 12h
Ana Souza - retirar assinatura - Rua Central, 87
''';

  test('separa nome, endereço, telefone e observação', () {
    final drafts = parseStops(raw);
    expect(drafts, hasLength(4));

    expect(drafts[0].client, 'João');
    expect(drafts[0].address, 'Rua das Flores, 120');
    expect(drafts[0].note, 'ligar antes');

    expect(drafts[1].client, 'Maria');
    expect(drafts[1].address, 'Av Brasil 900');
    expect(drafts[1].phone, '1199999-9999');
    expect(drafts[1].note, 'boleto');

    expect(drafts[2].client, 'Carlos');
    expect(drafts[2].address, 'Rua X 44');
    expect(drafts[2].note.toLowerCase(), contains('12h'));
    expect(drafts[2].windowEndMin, 12 * 60);

    expect(drafts[3].client, 'Ana Souza');
    expect(drafts[3].address, 'Rua Central, 87');
    expect(drafts[3].note, 'retirar assinatura');
  });

  test('cidade padrão entra no endereço', () {
    final drafts = parseStops('João - Rua das Flores, 120', defaultCity: 'São João da Boa Vista');
    expect(drafts.single.address, 'Rua das Flores, 120, São João da Boa Vista');
  });

  test('endereço com outra cidade não recebe a cidade padrão', () {
    final drafts = parseStops('Loja - Rua Augusta 1500, São Paulo', defaultCity: 'Aguaí');
    expect(drafts.single.address, 'Rua Augusta 1500, São Paulo');
  });

  test('marca endereço incompleto e duplicado', () {
    final drafts = parseStops('''
Pedro - ligar antes
João - Rua das Flores, 120
João - Rua das Flores, 120
''');
    expect(drafts[0].incomplete, isTrue);
    expect(drafts[2].duplicate, isTrue);
  });
}
