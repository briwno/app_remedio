import 'package:flutter/material.dart';
import '../models/notification_settings.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class ConfiguracoesScreen extends StatefulWidget {
  final StorageService storage;
  const ConfiguracoesScreen({super.key, required this.storage});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  late NotificationSettings _settings;

  static const _teal = Color(0xFF44B4A6);
  static const _accent = Color(0xFF9C7CDB);
  static const _warmBg = Color(0xFFF0EBE3);
  static const _darkText = Color(0xFF2D2D2D);

  @override
  void initState() {
    super.initState();
    _settings = widget.storage.carregarNotificationSettings();
  }

  Future<void> _salvar(NotificationSettings novoSettings) async {
    setState(() => _settings = novoSettings);
    await widget.storage.salvarNotificationSettings(novoSettings);
    final remedios = widget.storage.carregarRemedios();
    await NotificationService.agendarNotificacoesRemedios(remedios,
        settings: novoSettings);
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
                'Configurações',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                  height: 1.15,
                ),
              ),
            ),
          ),

          // Seção de Notificações
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.notifications_active_rounded,
                                color: _teal, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Notificações',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _darkText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),

                    // Lembrete antes
                    _buildNotifToggle(
                      icon: Icons.access_time,
                      color: _accent,
                      titulo: 'Lembrete antes do horário',
                      subtitulo: '${_settings.minutosAntes} min antes',
                      ativo: _settings.lembreteAntes,
                      onToggle: (v) =>
                          _salvar(_settings.copyWith(lembreteAntes: v)),
                      onTapConfig: _settings.lembreteAntes
                          ? () => _editarMinutos(
                                titulo: 'Minutos antes',
                                valorAtual: _settings.minutosAntes,
                                onSave: (v) =>
                                    _salvar(_settings.copyWith(minutosAntes: v)),
                              )
                          : null,
                    ),

                    // Lembrete na hora
                    _buildNotifToggle(
                      icon: Icons.medication_rounded,
                      color: _teal,
                      titulo: 'Lembrete na hora exata',
                      subtitulo: 'Avisa quando chegar o horário',
                      ativo: _settings.lembreteNaHora,
                      onToggle: (v) =>
                          _salvar(_settings.copyWith(lembreteNaHora: v)),
                    ),

                    // Lembrete depois (esqueceu?)
                    _buildNotifToggle(
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFE57373),
                      titulo: 'Lembrete "Esqueceu?"',
                      subtitulo: '${_settings.minutosDepois} min depois',
                      ativo: _settings.lembreteDepois,
                      onToggle: (v) =>
                          _salvar(_settings.copyWith(lembreteDepois: v)),
                      onTapConfig: _settings.lembreteDepois
                          ? () => _editarMinutos(
                                titulo: 'Minutos depois',
                                valorAtual: _settings.minutosDepois,
                                onSave: (v) =>
                                    _salvar(_settings.copyWith(minutosDepois: v)),
                              )
                          : null,
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),

          // Teste de notificação
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
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
                child: Column(
                  children: [
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.science_rounded,
                            color: _accent, size: 22),
                      ),
                      title: const Text(
                        'Testar notificação',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: _darkText),
                      ),
                      subtitle: Text(
                        'Envia uma notificação de teste agora',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        NotificationService.enviarNotificacaoTeste();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Notificação de teste enviada!'),
                            backgroundColor: _teal,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.timer_rounded,
                            color: Colors.orange, size: 22),
                      ),
                      title: const Text(
                        'Testar em 5 segundos',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, color: _darkText),
                      ),
                      subtitle: Text(
                        'Agenda notificação para 5s — pode fechar o app!',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        NotificationService.agendarNotificacaoEm5Segundos();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                                '⏱️ Notificação agendada! Pode fechar o app.'),
                            backgroundColor: Colors.orange,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Resumo ativo
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: _buildResumoNotificacoes(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildNotifToggle({
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
    required bool ativo,
    required ValueChanged<bool> onToggle,
    VoidCallback? onTapConfig,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: ativo ? 0.12 : 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: ativo ? color : Colors.grey[400], size: 20),
        ),
        title: Text(
          titulo,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: ativo ? _darkText : Colors.grey[500],
            fontSize: 15,
          ),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                subtitulo,
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
            if (onTapConfig != null)
              GestureDetector(
                onTap: onTapConfig,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Alterar',
                    style: TextStyle(
                      fontSize: 12,
                      color: _teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        trailing: Switch(
          value: ativo,
          activeThumbColor: _teal,
          onChanged: onToggle,
        ),
      ),
    );
  }

  Future<void> _editarMinutos({
    required String titulo,
    required int valorAtual,
    required ValueChanged<int> onSave,
  }) async {
    final opcoes = [5, 10, 15, 20, 30, 45, 60];
    final resultado = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: opcoes.map((min) {
            final selecionado = min == valorAtual;
            return ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              selected: selecionado,
              selectedTileColor: _teal.withValues(alpha: 0.1),
              leading: Icon(
                selecionado
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selecionado ? _teal : Colors.grey[400],
              ),
              title: Text(
                '$min minutos',
                style: TextStyle(
                  fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                  color: selecionado ? _teal : _darkText,
                ),
              ),
              onTap: () => Navigator.pop(ctx, min),
            );
          }).toList(),
        ),
      ),
    );
    if (resultado != null) {
      onSave(resultado);
    }
  }

  Widget _buildResumoNotificacoes() {
    final remedios = widget.storage.carregarRemedios();
    final diarios = remedios.where((r) => r.diario && r.ativo).toList();
    int totalHorarios = 0;
    for (final r in diarios) {
      totalHorarios += r.horarios.length;
    }

    int notifsPorHorario = 0;
    if (_settings.lembreteAntes) notifsPorHorario++;
    if (_settings.lembreteNaHora) notifsPorHorario++;
    if (_settings.lembreteDepois) notifsPorHorario++;

    final totalNotifs = totalHorarios * notifsPorHorario;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF44B4A6), Color(0xFF5CC4B7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _teal.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Resumo ativo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalNotifs notificações diárias para $totalHorarios horário${totalHorarios == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
