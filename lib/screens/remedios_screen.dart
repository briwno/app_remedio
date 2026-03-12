import 'package:flutter/material.dart';
import '../models/remedio.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class RemediosScreen extends StatefulWidget {
  final StorageService storage;
  const RemediosScreen({super.key, required this.storage});

  @override
  State<RemediosScreen> createState() => _RemediosScreenState();
}

class _RemediosScreenState extends State<RemediosScreen> {
  late List<Remedio> _remedios;

  static const _teal = Color(0xFF44B4A6);
  static const _accent = Color(0xFF9C7CDB);
  static const _warmBg = Color(0xFFF0EBE3);
  static const _darkText = Color(0xFF2D2D2D);

  @override
  void initState() {
    super.initState();
    _remedios = widget.storage.carregarRemedios();
    widget.storage.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.storage.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      setState(() {
        _remedios = widget.storage.carregarRemedios();
      });
    }
  }

  void _atualizar() {
    setState(() {
      _remedios = widget.storage.carregarRemedios();
    });
    final settings = widget.storage.carregarNotificationSettings();
    NotificationService.agendarNotificacoesRemedios(_remedios, settings: settings);
  }

  Future<void> _adicionarRemedio() async {
    final resultado = await showDialog<Remedio>(
      context: context,
      builder: (ctx) => const _RemedioDialog(),
    );
    if (resultado != null) {
      await widget.storage.adicionarRemedio(resultado);
      _atualizar();
    }
  }

  Future<void> _editarRemedio(Remedio remedio) async {
    final resultado = await showDialog<Remedio>(
      context: context,
      builder: (ctx) => _RemedioDialog(remedio: remedio),
    );
    if (resultado != null) {
      await widget.storage.atualizarRemedio(resultado);
      _atualizar();
    }
  }

  Future<void> _removerRemedio(Remedio remedio) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remover Remédio'),
        content: Text('Deseja remover "${remedio.nome}" e todo seu histórico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[400]),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmado == true) {
      await widget.storage.removerRemedio(remedio.id);
      _atualizar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _warmBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              child: const Text(
                'Meus\nRemédios',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                  height: 1.15,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final remedio = _remedios[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: remedio.diario
                              ? _teal.withValues(alpha: 0.1)
                              : _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          remedio.diario
                              ? Icons.medication_rounded
                              : Icons.medical_services_rounded,
                          color: remedio.diario ? _teal : _accent,
                        ),
                      ),
                      title: Text(
                        remedio.nome,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _darkText,
                          decoration:
                              remedio.ativo ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(
                        remedio.diario
                            ? 'Diário - ${remedio.horarios.join(", ")}'
                            : 'Quando precisar',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: remedio.ativo,
                            activeThumbColor: _teal,
                            onChanged: (v) async {
                              await widget.storage.atualizarRemedio(
                                  remedio.copyWith(ativo: v));
                              _atualizar();
                            },
                          ),
                          PopupMenuButton(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'editar',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'remover',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_rounded,
                                        size: 18, color: Colors.red[400]),
                                    const SizedBox(width: 8),
                                    Text('Remover',
                                        style: TextStyle(color: Colors.red[400])),
                                  ],
                                ),
                              ),
                            ],
                            onSelected: (v) {
                              if (v == 'editar') _editarRemedio(remedio);
                              if (v == 'remover') _removerRemedio(remedio);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: _remedios.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionarRemedio,
        backgroundColor: _teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Remédio'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

// --- Dialog para adicionar/editar remédio ---

class _RemedioDialog extends StatefulWidget {
  final Remedio? remedio;
  const _RemedioDialog({this.remedio});

  @override
  State<_RemedioDialog> createState() => _RemedioDialogState();
}

class _RemedioDialogState extends State<_RemedioDialog> {
  late TextEditingController _nomeCtrl;
  late TextEditingController _dosagemCtrl;
  late bool _diario;
  late List<String> _horarios;

  static const _teal = Color(0xFF44B4A6);

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.remedio?.nome ?? '');
    _dosagemCtrl = TextEditingController(text: widget.remedio?.dosagem ?? '');
    _diario = widget.remedio?.diario ?? true;
    _horarios = List.from(widget.remedio?.horarios ?? []);
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _dosagemCtrl.dispose();
    super.dispose();
  }

  Future<void> _adicionarHorario() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _horarios.add(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        );
        _horarios.sort();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editando = widget.remedio != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(editando ? 'Editar Remédio' : 'Novo Remédio'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nomeCtrl,
              decoration: InputDecoration(
                labelText: 'Nome do remédio',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _teal, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosagemCtrl,
              decoration: InputDecoration(
                labelText: 'Dosagem (opcional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _teal, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Tomar todo dia'),
              subtitle: Text(_diario ? 'Com horários fixos' : 'Só quando precisar'),
              value: _diario,
              activeThumbColor: _teal,
              onChanged: (v) => setState(() => _diario = v),
              contentPadding: EdgeInsets.zero,
            ),
            if (_diario) ...[
              const SizedBox(height: 8),
              const Text('Horários:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  ..._horarios.map((h) => Chip(
                        label: Text(h),
                        onDeleted: () =>
                            setState(() => _horarios.remove(h)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      )),
                  ActionChip(
                    label: const Icon(Icons.add, size: 18),
                    onPressed: _adicionarHorario,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ],
          ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_nomeCtrl.text.trim().isEmpty) return;
            final remedio = Remedio(
              id: widget.remedio?.id ??
                  _nomeCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
              nome: _nomeCtrl.text.trim(),
              dosagem:
                  _dosagemCtrl.text.trim().isEmpty ? null : _dosagemCtrl.text.trim(),
              horarios: _diario ? _horarios : [],
              diario: _diario,
              ativo: widget.remedio?.ativo ?? true,
            );
            Navigator.pop(context, remedio);
          },
          style: FilledButton.styleFrom(
            backgroundColor: _teal,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(editando ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }
}
