# S Planner

Aplicativo em Flutter que monta a melhor rota do dia a partir de uma lista de endereços.

Projeto Integrado de Desenvolvimento Mobile, Análise e Desenvolvimento de Sistemas, UNIFEOB.
Beneficiário: Leandra de Souza Piani, entrega de doces (revenda Fazenda), Aguaí-SP. CNPJ 69.251.628/0001-66.

Alunos:

- Glauber Mariano Lellis Junior, RA 1012023200186 ([@niceschemes](https://github.com/niceschemes))
- Eduarda Celina Ezequiel Maltempe, RA 24001738 ([@dudamaltempe](https://github.com/dudamaltempe))
- João Gabriel da Silva, RA 25001142 ([@joaosilva-prog](https://github.com/joaosilva-prog))

## O que o aplicativo faz

- Recebe as paradas digitadas (uma por linha) ou lidas de um PDF de pedido.
- Localiza cada endereço no mapa. O que não for localizado continua na lista, marcado em amarelo.
- Parte sempre da localização atual do celular e organiza a sequência pela menor distância.
- Aceita endereços de qualquer cidade. Sem cidade escrita, usa a cidade onde o celular está.
- O botão Iniciar abre o Google Maps com o trajeto até a próxima parada. Ao voltar para o app, ele passa para a parada seguinte.
- Registra o status de cada parada e guarda o histórico.

## Tecnologias

- Flutter e Dart
- OpenStreetMap (mapa), Nominatim (busca de endereço) e OSRM (traçado das ruas)
- geolocator, url_launcher e shared_preferences

## Como rodar

```bash
flutter pub get
flutter run
```

Testes:

```bash
flutter test
```

APK:

```bash
flutter build apk --release
```
