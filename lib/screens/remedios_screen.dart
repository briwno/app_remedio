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

  @override
  void initState() {
    super.initState();
    _remedios = widget.storage.carregarRemedios();
  }

  void _atualizar() {
    setState(() {
      _remedios = widget.storage.carregarRemedios();
    });
    // Reagendar notificações
    NotificationService.agendarNotificacoesRemedios(_remedios);
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
        title: const Text('Remover Remédio'),
        content: Text('Deseja remover "${remedio.nome}" e todo seu histórico?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
      backgroundColor: const Color(0xFFF5F0FF),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: const Text(
                '⚙️ Meus Remédios',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final remedio = _remedios[index];
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: remedio.diario
                              ? const Color(0xFFE8DEF8)
                              : const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          remedio.diario
                              ? Icons.medication
                              : Icons.medical_services,
                          color: remedio.diario
                              ? const Color(0xFF7C4DFF)
                              : Colors.orange,
                        ),
                      ),
                      title: Text(
                        remedio.nome,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration:
                              remedio.ativo ? null : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(
                        remedio.diario
                            ? 'Diário - ${remedio.horarios.join(", ")}'
                            : 'Quando precisar',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: remedio.ativo,
                            activeColor: const Color(0xFF7C4DFF),
                            onChanged: (v) async {
                              await widget.storage.atualizarRemedio(
                                  remedio.copyWith(ativo: v));
                              _atualizar();
                            },
                          ),
                          PopupMenuButton(
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                value: 'editar',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Editar'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'remover',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete,
                                        size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Remover',
                                        style: TextStyle(color: Colors.red)),
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
        backgroundColor: const Color(0xFF7C4DFF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Novo Remédio'),
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
      title: Text(editando ? 'Editar Remédio' : 'Novo Remédio'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nomeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do remédio',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dosagemCtrl,
              decoration: const InputDecoration(
                labelText: 'Dosagem (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Tomar todo dia'),
              subtitle: Text(_diario ? 'Com horários fixos' : 'Só quando precisar'),
              value: _diario,
              activeColor: const Color(0xFF7C4DFF),
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
                      )),
                  ActionChip(
                    label: const Icon(Icons.add, size: 18),
                    onPressed: _adicionarHorario,
                  ),
                ],
              ),
            ],
          ],
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
            backgroundColor: const Color(0xFF7C4DFF),
          ),
          child: Text(editando ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }
}
