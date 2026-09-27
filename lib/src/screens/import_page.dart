import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../parser.dart';
import '../pdf_orders.dart';
import '../planner_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

List<String> draftWarnings(DraftStop draft) {
  return [
    if (draft.duplicate) 'Possível duplicada',
    if (draft.notFound && draft.address.trim().isNotEmpty) 'Não achei no mapa',
    if (draft.incomplete && draft.lat != null) 'Endereço incompleto',
    if (draft.clientUncertain) 'Nome incerto',
    if (draft.invalid && draft.address.trim().isEmpty) 'Linha inválida',
  ];
}

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, this.replace = false, this.manualFirst = true});

  final bool replace;
  final bool manualFirst;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _DraftEditors {
  _DraftEditors(this.draft)
      : client = TextEditingController(text: draft.client),
        address = TextEditingController(text: draft.address),
        phone = TextEditingController(text: draft.phone),
        note = TextEditingController(text: draft.note);

  final DraftStop draft;
  final TextEditingController client;
  final TextEditingController address;
  final TextEditingController phone;
  final TextEditingController note;
  bool removed = false;

  void dispose() {
    client.dispose();
    address.dispose();
    phone.dispose();
    note.dispose();
  }
}

class _DocumentItem {
  _DocumentItem(this.fileName, this.editors, this.error);

  final String fileName;
  final List<_DraftEditors> editors;
  final String? error;
}

class _ImportPageState extends State<ImportPage> {
  final _raw = TextEditingController();
  final _city = TextEditingController();
  final List<_DraftEditors> _rows = [];
  final List<_DocumentItem> _docs = [];
  bool _reading = false;
  bool _planning = false;
  bool _cityTouched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cityTouched) return;
    _cityTouched = true;
    PlannerScope.of(context).currentCity().then((city) {
      if (!mounted || city == null || _city.text.trim().isNotEmpty) return;
      _city.text = city;
    });
  }

  @override
  void dispose() {
    _raw.dispose();
    _city.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _read() {
    final fromDocs = _docs.expand((doc) => doc.editors).toSet();
    for (final row in _rows) {
      if (!fromDocs.contains(row)) row.dispose();
    }
    final drafts = parseStops(_raw.text, defaultCity: _city.text);
    setState(() {
      _rows
        ..clear()
        ..addAll(fromDocs)
        ..addAll(drafts.map(_DraftEditors.new));
    });
  }

  Future<void> _pickPdfs() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      dialogTitle: 'Pedidos em PDF',
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _reading = true);
    for (final file in files) {
      try {
        final bytes = await file.readAsBytes();
        final text = textFromPdfBytes(bytes);
        if (text.trim().length < 12) {
          _docs.add(
            _DocumentItem(
              file.name,
              const [],
              'Este PDF não tem texto. Se for só uma foto, o endereço precisa estar escrito no arquivo.',
            ),
          );
          continue;
        }
        final drafts = ordersFromDocumentText(text, fileName: file.name, defaultCity: _city.text);
        if (!mounted) return;
        final controller = PlannerScope.of(context);
        for (final draft in drafts) {
          if (draft.address.trim().isEmpty) {
            draft.invalid = true;
            continue;
          }
          final place = await controller.confirmStop(draft.address);
          if (!mounted) return;
          if (place == null) {
            draft.notFound = true;
            draft.addressUncertain = true;
          } else {
            draft.lat = place.latitude;
            draft.lng = place.longitude;
            draft.notFound = false;
            draft.addressUncertain = false;
            draft.incomplete = false;
            draft.invalid = false;
          }
        }
        final editors = drafts.map(_DraftEditors.new).toList();
        _rows.addAll(editors);
        _docs.add(_DocumentItem(file.name, editors, null));
      } catch (_) {
        _docs.add(_DocumentItem(file.name, const [], 'Não consegui abrir este PDF.'));
      }
    }
    flagDuplicateDrafts([
      for (final row in _rows)
        if (!row.removed) row.draft,
    ]);
    if (mounted) setState(() => _reading = false);
  }

  void _removeDoc(_DocumentItem doc) {
    for (final editor in doc.editors) {
      editor.removed = true;
    }
    setState(() => _docs.remove(doc));
  }

  void _confirm() {
    final messenger = ScaffoldMessenger.of(context);
    final controller = PlannerScope.of(context);
    final fromDocs = _docs.isNotEmpty;
    setState(() => _planning = true);
    () async {
      final drafts = <DraftStop>[];
      try {
        for (final row in _rows) {
          if (row.removed) continue;
          row.draft.client = row.client.text.trim().isEmpty ? 'Sem nome' : row.client.text.trim();
          row.draft.phone = row.phone.text.trim();
          row.draft.note = row.note.text.trim();
          final address = row.address.text.trim();
          final changed = address != row.draft.address;
          row.draft.address = address;
          if (address.isEmpty) {
            row.draft.invalid = true;
            row.draft.lat = null;
            row.draft.lng = null;
          } else if (changed || (row.draft.lat == null && !row.draft.notFound)) {
            final place = await controller.confirmStop(address);
            if (!mounted) return;
            row.draft.invalid = false;
            if (place == null) {
              row.draft.lat = null;
              row.draft.lng = null;
              row.draft.notFound = true;
              row.draft.addressUncertain = true;
            } else {
              row.draft.lat = place.latitude;
              row.draft.lng = place.longitude;
              row.draft.notFound = false;
              row.draft.addressUncertain = false;
              row.draft.incomplete = false;
            }
          }
          drafts.add(row.draft);
        }
        final kept = drafts.where((draft) => !draft.invalid).toList();
        if (kept.isEmpty) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Nenhuma parada com endereço para adicionar.')),
          );
          return;
        }
        final missed = kept.where((draft) => draft.lat == null).length;
        await controller.planImported(drafts, replace: fromDocs || widget.replace);
        if (!mounted) return;
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              missed == 0
                  ? '${kept.length} paradas na rota.'
                  : missed == 1
                      ? '${kept.length} paradas na rota. 1 endereço não foi localizado no mapa. Confira em amarelo.'
                      : '${kept.length} paradas na rota. $missed endereços não foram localizados no mapa. Confira em amarelo.',
            ),
          ),
        );
      } finally {
        if (mounted) setState(() => _planning = false);
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final active = _rows.where((row) => !row.removed && !row.draft.invalid).length;
    final uncertain = _rows.where((row) => !row.removed && (row.draft.incomplete || row.draft.duplicate || row.draft.clientUncertain)).length;
    final manual = <Widget>[
      Text(
        widget.manualFirst ? 'Endereços na mão' : 'Ou digite os endereços',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      const Text(
        'Uma parada por linha. Pode ser só o endereço, ou nome - endereço.',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _raw,
        minLines: 8,
        maxLines: 12,
        decoration: const InputDecoration(
          alignLabelWithHint: true,
          labelText: 'Digite ou cole os endereços',
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(onPressed: _read, child: const Text('Ler paradas')),
      ),
      if (_rows.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(
          uncertain == 0 ? '$active paradas prontas' : '$uncertain para conferir',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (final row in _rows)
          if (!row.removed) _Preview(row: row, onChanged: () => setState(() {})),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: active == 0 || _planning ? null : _confirm,
          child: Text(_docs.isNotEmpty ? 'Planejar $active pedidos' : 'Adicionar $active paradas'),
        ),
      ],
    ];
    final pdf = <Widget>[
      const Text('Documentação dos pedidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      const Text(
        'Cada PDF é um pedido. O app procura o campo de endereço e monta a sequência.',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _reading || _planning ? null : _pickPdfs,
        icon: _reading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.upload_file, size: 18),
        label: Text(_reading ? 'Conferindo no mapa' : 'Adicionar PDFs'),
      ),
      if (_docs.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final doc in _docs) _DocumentTile(doc: doc, onRemove: () => _removeDoc(doc)),
      ],
    ];
    return Scaffold(
      appBar: appPageBar(context, widget.manualFirst ? 'Adicionar manual' : 'Adicionar PDF'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          TextField(
            controller: _city,
            decoration: const InputDecoration(
              labelText: 'Cidade padrão',
              helperText: 'Vem da sua localização. Endereço com outra cidade escrita mantém a cidade dele.',
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.manualFirst) ...manual else ...pdf,
          const SizedBox(height: 16),
          if (widget.manualFirst) ...pdf else ...manual,
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({required this.doc, required this.onRemove});

  final _DocumentItem doc;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final address = doc.editors.map((editor) => editor.draft.address).where((item) => item.isNotEmpty).join(' · ');
    final detail = doc.error ?? (address.isEmpty ? 'Endereço não encontrado. Preencha o campo abaixo.' : address);
    final warn = doc.error != null || address.isEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warn ? AppColors.amber : AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 18, color: AppColors.mint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remover',
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.row, required this.onChanged});

  final _DraftEditors row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final warn = row.draft.incomplete || row.draft.duplicate || row.draft.clientUncertain || row.draft.invalid;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: warn ? AppColors.amber : AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  draftWarnings(row.draft).join(' · '),
                  style: const TextStyle(color: AppColors.amber, fontSize: 12),
                ),
              ),
              IconButton(
                tooltip: 'Remover',
                onPressed: () {
                  row.removed = true;
                  onChanged();
                },
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          TextField(controller: row.client, decoration: const InputDecoration(labelText: 'Cliente')),
          const SizedBox(height: 6),
          TextField(controller: row.address, decoration: const InputDecoration(labelText: 'Endereço')),
          const SizedBox(height: 6),
          TextField(controller: row.phone, decoration: const InputDecoration(labelText: 'Telefone')),
          const SizedBox(height: 6),
          TextField(controller: row.note, decoration: const InputDecoration(labelText: 'Observação')),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
