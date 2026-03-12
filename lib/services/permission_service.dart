import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionItem {
  final String nome;
  final String descricao;
  final IconData icone;
  final bool concedida;

  const PermissionItem({
    required this.nome,
    required this.descricao,
    required this.icone,
    required this.concedida,
  });
}

class PermissionService {
  /// Verifica e solicita todas as permissões necessárias.
  /// Retorna true se todas estão OK.
  static Future<bool> verificarPermissoes() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    final notif = await Permission.notification.status;
    final alarm = await Permission.scheduleExactAlarm.status;

    return notif.isGranted && alarm.isGranted;
  }

  /// Retorna lista de permissões com status atual.
  static Future<List<PermissionItem>> listarPermissoes() async {
    final notif = await Permission.notification.status;
    final alarm = await Permission.scheduleExactAlarm.status;

    return [
      PermissionItem(
        nome: 'Notificações',
        descricao: 'Para lembrar dos remédios na hora certa',
        icone: Icons.notifications_active,
        concedida: notif.isGranted,
      ),
      PermissionItem(
        nome: 'Alarmes exatos',
        descricao: 'Para agendar lembretes no horário preciso',
        icone: Icons.alarm,
        concedida: alarm.isGranted,
      ),
    ];
  }

  /// Solicita todas as permissões pendentes.
  /// Retorna true se todas foram concedidas.
  static Future<bool> solicitarPermissoes() async {
    // Notificações
    if (!(await Permission.notification.isGranted)) {
      final result = await Permission.notification.request();
      if (result.isPermanentlyDenied) {
        await openAppSettings();
      }
    }

    // Alarmes exatos
    if (!(await Permission.scheduleExactAlarm.isGranted)) {
      await Permission.scheduleExactAlarm.request();
    }

    return verificarPermissoes();
  }

  /// Mostra o dialog de permissões se alguma estiver faltando.
  static Future<void> verificarEMostrarDialog(BuildContext context) async {
    final ok = await verificarPermissoes();
    if (ok) return;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _PermissionDialog(),
    );
  }
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog();

  @override
  State<_PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog>
    with WidgetsBindingObserver {
  List<PermissionItem> _permissoes = [];
  bool _carregando = true;
  bool _solicitando = false;

  static const _teal = Color(0xFF44B4A6);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _carregar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Quando o usuário volta das configurações do sistema, recarrega
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _carregar();
    }
  }

  Future<void> _carregar() async {
    final lista = await PermissionService.listarPermissoes();
    if (mounted) {
      setState(() {
        _permissoes = lista;
        _carregando = false;
      });

      // Se todas concedidas, fecha dialog
      if (lista.every((p) => p.concedida)) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _solicitar() async {
    setState(() => _solicitando = true);
    await PermissionService.solicitarPermissoes();
    await _carregar();
    if (mounted) setState(() => _solicitando = false);
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = _permissoes.where((p) => !p.concedida).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Text('🔔', style: TextStyle(fontSize: 24)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Permissões necessárias',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nanay, para os lembretes funcionarem direitinho, '
                      'precisa dessas permissões:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._permissoes.map((p) => _buildItem(p)),
                    if (pendentes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${pendentes.length} permissão(ões) pendente(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        if (pendentes.isEmpty || !_carregando)
          TextButton(
            onPressed: pendentes.isEmpty
                ? () => Navigator.of(context).pop()
                : () => Navigator.of(context).pop(),
            child: Text(
              pendentes.isEmpty ? 'Tudo certo!' : 'Depois',
              style: TextStyle(
                color: pendentes.isEmpty ? _teal : Colors.grey,
              ),
            ),
          ),
        if (pendentes.isNotEmpty)
          FilledButton.icon(
            onPressed: _solicitando ? null : _solicitar,
            icon: _solicitando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle, size: 18),
            label: const Text('Permitir'),
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildItem(PermissionItem p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.concedida
                  ? _teal.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              p.icone,
              size: 20,
              color: p.concedida ? _teal : Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.nome,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      p.concedida ? Icons.check_circle : Icons.error,
                      size: 16,
                      color: p.concedida ? _teal : Colors.orange,
                    ),
                  ],
                ),
                Text(
                  p.descricao,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
