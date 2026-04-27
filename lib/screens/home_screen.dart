import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/remedio.dart';
import '../models/registro.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storage;
  const HomeScreen({super.key, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _diaSelecionado = DateTime.now();
  late List<Remedio> _remedios;
  final _dateFormat = DateFormat('EEEE, d MMM yyyy', 'pt_BR');

  static const _teal = Color(0xFF44B4A6);
  static const _tealDark = Color(0xFF2E9E8F);
  static const _warmBg = Color(0xFFF0EBE3);
  static const _accent = Color(0xFF9C7CDB);
  static const _darkText = Color(0xFF2D2D2D);

  DateTime get _diaLimpo => DateTime(
      _diaSelecionado.year, _diaSelecionado.month, _diaSelecionado.day);

  bool get _ehHoje {
    final agora = DateTime.now();
    return _diaLimpo == DateTime(agora.year, agora.month, agora.day);
  }

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

  void _atualizarRemedios() {
    setState(() {
      _remedios = widget.storage.carregarRemedios();
    });
    // Recarrega mensagem do dia do banco
    widget.storage.atualizarMensagemDoDia();
  }

  Future<void> _reagendarNotificacoesHoje() async {
    final remedios = widget.storage.carregarRemedios();
    final settings = widget.storage.carregarNotificationSettings();
    final registrosHoje = widget.storage.registrosDoDia(DateTime.now());

    await NotificationService.agendarNotificacoesRemedios(
      remedios,
      settings: settings,
      registrosHoje: registrosHoje,
    );
  }

  Future<void> _toggleRemedio(Remedio remedio, String? horario) async {
    final tomado = widget.storage.foiTomado(remedio.id, _diaLimpo, horario);
    if (tomado) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Desmarcar'),
          content: Text(
              'Deseja desmarcar ${remedio.nome} (${horario ?? "SOS"})?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red[400]),
              child: const Text('Desmarcar'),
            ),
          ],
        ),
      );
      if (confirmar == true) {
        await widget.storage.removerRegistro(remedio.id, _diaLimpo, horario);
        await _reagendarNotificacoesHoje();
        setState(() {});
      }
    } else {
      await widget.storage.registrarTomado(Registro(
        remedioId: remedio.id,
        dataHora: DateTime.now(),
        horarioPrevisto: horario,
      ));
      await _reagendarNotificacoesHoje();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('${remedio.nome} marcado às ${horario ?? DateFormat('HH:mm').format(DateTime.now())}'),
              ],
            ),
            backgroundColor: _teal,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _registrarSOS(Remedio remedio) async {
    final agora = DateTime.now();
    final horaStr = DateFormat('HH:mm').format(agora);
    await widget.storage.registrarTomado(Registro(
      remedioId: remedio.id,
      dataHora: agora,
      horarioPrevisto: horaStr,
    ));
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${remedio.nome} registrado às $horaStr'),
          backgroundColor: _teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _statusHorario(Remedio remedio, String horario) {
    final tomado = widget.storage.foiTomado(remedio.id, _diaLimpo, horario);
    if (tomado) return 'tomado';
    if (!_ehHoje) return 'perdido';

    final agora = DateTime.now();
    final partes = horario.split(':');
    final horaRemedio = DateTime(
      agora.year, agora.month, agora.day,
      int.parse(partes[0]), int.parse(partes[1]),
    );

    final diff = horaRemedio.difference(agora).inMinutes;
    if (diff > 15) return 'agendado';
    if (diff > 0) return 'em_breve';
    if (diff > -30) return 'atrasado';
    return 'perdido';
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'tomado': return _teal;
      case 'em_breve': return _accent;
      case 'atrasado': return const Color(0xFFE57373);
      case 'perdido': return Colors.grey;
      default: return _tealDark;
    }
  }

  IconData _iconeStatus(String status) {
    switch (status) {
      case 'tomado': return Icons.check_circle;
      case 'em_breve': return Icons.access_time;
      case 'atrasado': return Icons.warning_amber_rounded;
      case 'perdido': return Icons.cancel_outlined;
      default: return Icons.schedule;
    }
  }

  String _textoStatus(String status) {
    switch (status) {
      case 'tomado': return 'Tomado ✓';
      case 'em_breve': return 'Em breve';
      case 'atrasado': return 'Atrasado!';
      case 'perdido': return 'Não tomou';
      default: return 'Agendado';
    }
  }

  String _statusDoDia(DateTime dia) {
    final remedios = _remedios.where((r) => r.diario && r.ativo).toList();
    if (remedios.isEmpty) return 'sem_dados';
    int total = 0;
    int tomados = 0;
    for (final r in remedios) {
      for (final h in r.horarios) {
        total++;
        if (widget.storage.foiTomado(r.id, dia, h)) tomados++;
      }
    }
    if (total == 0) return 'sem_dados';
    if (tomados == total) return 'completo';
    if (tomados > 0) return 'parcial';
    return 'nenhum';
  }

  @override
  Widget build(BuildContext context) {
    final diarios = _remedios.where((r) => r.diario && r.ativo).toList();
    final sos = _remedios.where((r) => !r.diario && r.ativo).toList();
    final registrosSOS = widget.storage.registrosDoDia(_diaLimpo);

    return Scaffold(
      backgroundColor: _warmBg,
      body: RefreshIndicator(
        color: _teal,
        onRefresh: () async => _atualizarRemedios(),
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            final data = await showDatePicker(
                              context: context,
                              initialDate: _diaSelecionado,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                              locale: const Locale('pt', 'BR'),
                            );
                            if (data != null) {
                              setState(() => _diaSelecionado = data);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _ehHoje
                                ? Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: 'HOJE, ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text: DateFormat('EEEE, d MMM yyyy', 'pt_BR').format(_diaSelecionado),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Text(
                                    _dateFormat.format(_diaSelecionado),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.notifications_none_rounded,
                              color: Colors.grey[600], size: 26),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Remédios\nda Nanay 💊',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                        height: 1.15,
                      ),
                    ),
                    if (widget.storage.mensagemDoDia.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Text('💌', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.storage.mensagemDoDia,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildWeekStrip(),
                  ],
                ),
              ),
            ),

            // Resumo
            if (_ehHoje && diarios.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: _buildResumoHoje(diarios),
                ),
              ),

            // Remédios diários
            if (diarios.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text(
                    'Cronograma da Nanay',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildRemedioDiarioCard(diarios[index]),
                  childCount: diarios.length,
                ),
              ),
            ],

            // Remédios SOS
            if (sos.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Text(
                    'Quando precisar',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final remedio = sos[index];
                    final registrosDoRemedio = registrosSOS
                        .where((r) => r.remedioId == remedio.id)
                        .toList();
                    return _buildRemedioSOSCard(remedio, registrosDoRemedio);
                  },
                  childCount: sos.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekStrip() {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final inicioSemana = _diaLimpo.subtract(Duration(days: _diaLimpo.weekday - 1));
    final diasDaSemana = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dia = inicioSemana.add(Duration(days: i));
        final diaLimpo = DateTime(dia.year, dia.month, dia.day);
        final ehSelecionado = _diaLimpo == diaLimpo;
        final ehHoje = diaLimpo == hoje;
        final ehFuturo = diaLimpo.isAfter(hoje);

        String? emoji;
        if (!ehFuturo && !ehHoje) {
          final status = _statusDoDia(diaLimpo);
          if (status == 'completo') {
            emoji = '✅';
          } else if (status == 'parcial') {
            emoji = '⚠️';
          } else if (status == 'nenhum') {
            emoji = '❌';
          }
        }

        return GestureDetector(
          onTap: ehFuturo ? null : () => setState(() => _diaSelecionado = dia),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: ehSelecionado
                  ? (ehHoje ? _accent : _teal)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  diasDaSemana[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ehSelecionado ? Colors.white : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${dia.day}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: ehSelecionado ? FontWeight.bold : FontWeight.w600,
                    color: ehSelecionado
                        ? Colors.white
                        : ehFuturo ? Colors.grey[300] : _darkText,
                  ),
                ),
                const SizedBox(height: 4),
                if (emoji != null)
                  Text(emoji, style: const TextStyle(fontSize: 10))
                else
                  const SizedBox(height: 14),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildResumoHoje(List<Remedio> diarios) {
    int total = 0;
    int tomados = 0;
    for (final r in diarios) {
      for (final h in r.horarios) {
        total++;
        if (widget.storage.foiTomado(r.id, _diaLimpo, h)) tomados++;
      }
    }
    final progresso = total > 0 ? tomados / total : 0.0;

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
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progresso,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                  strokeWidth: 5,
                ),
                Text(
                  '${(progresso * 100).round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Progresso de hoje',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$tomados de $total remédios tomados',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.medication_rounded, color: Colors.white, size: 32),
        ],
      ),
    );
  }

  Widget _buildRemedioDiarioCard(Remedio remedio) {
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medication_rounded,
                        color: _teal, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          remedio.nome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _darkText,
                          ),
                        ),
                        if (remedio.dosagem != null)
                          Text(
                            remedio.dosagem!,
                            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...remedio.horarios.map((h) => _buildHorarioTile(remedio, h)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorarioTile(Remedio remedio, String horario) {
    final status = _statusHorario(remedio, horario);
    final tomado = status == 'tomado';
    final cor = _corStatus(status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Dismissible(
        key: Key('${remedio.id}_${horario}_$tomado'),
        direction: tomado
            ? DismissDirection.none
            : DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          if (!tomado) {
            await _toggleRemedio(remedio, horario);
            return false; // don't remove from tree, state handles it
          }
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: _teal, size: 28),
              SizedBox(width: 8),
              Text(
                'Marcar como tomado',
                style: TextStyle(
                  color: _teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _toggleRemedio(remedio, horario),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: tomado
                    ? _teal.withValues(alpha: 0.08)
                    : cor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: tomado
                      ? _teal.withValues(alpha: 0.4)
                      : cor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: tomado
                          ? _teal.withValues(alpha: 0.15)
                          : cor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _iconeStatus(status),
                      color: tomado ? _teal : cor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    horario,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: tomado ? _teal : cor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  if (!tomado && _ehHoje)
                    _PulsingTomarButton(
                      pulsar: status == 'em_breve' || status == 'atrasado',
                      onPressed: () => _toggleRemedio(remedio, horario),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tomado ? _teal : cor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _textoStatus(status),
                        style: TextStyle(
                          fontSize: 12,
                          color: tomado ? Colors.white : cor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemedioSOSCard(Remedio remedio, List<Registro> registros) {
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medical_services_rounded,
                        color: _accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          remedio.nome,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _darkText,
                          ),
                        ),
                        Text(
                          remedio.dosagem ?? 'Usar quando precisar',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  if (_ehHoje)
                    FilledButton.icon(
                      onPressed: () => _registrarSOS(remedio),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tomar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                ],
              ),
              if (registros.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: Colors.grey[200]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Registros neste dia (${registros.length}x):',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...registros.map((r) => _buildRegistroSOSTile(remedio, r)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegistroSOSTile(Remedio remedio, Registro registro) {
    final dataHora = DateFormat('dd/MM HH:mm', 'pt_BR').format(registro.dataHora);
    final horaCompleta = DateFormat('HH:mm:ss').format(registro.dataHora);
    final diferencaDias = DateTime.now().difference(registro.dataHora).inDays;
    String descricao = '';
    if (diferencaDias == 0) {
      descricao = 'Hoje às $horaCompleta';
    } else if (diferencaDias == 1) {
      descricao = 'Ontem às $horaCompleta';
    } else {
      descricao = '$dataHora:${registro.dataHora.second.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _teal.withValues(alpha: 0.2), width: 1),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle, color: _teal, size: 18),
        ),
        title: Text(
          descricao,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _darkText,
          ),
        ),
        subtitle: _ehHoje
            ? Text(
                'Toque para desmarcar',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              )
            : null,
        trailing: _ehHoje
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: Colors.red[400],
                onPressed: () => _removerRegistroSOS(remedio, registro),
                tooltip: 'Desmarcar',
              )
            : null,
        onTap: _ehHoje ? () => _removerRegistroSOS(remedio, registro) : null,
      ),
    );
  }

  Future<void> _removerRegistroSOS(Remedio remedio, Registro registro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Desmarcar registro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deseja remover este registro de ${remedio.nome}?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: _accent),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm:ss', 'pt_BR')
                        .format(registro.dataHora),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red[400]),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await widget.storage.removerRegistroEspecifico(registro);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.white),
                const SizedBox(width: 8),
                Text('Registro de ${remedio.nome} removido'),
              ],
            ),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _PulsingTomarButton extends StatefulWidget {
  final bool pulsar;
  final VoidCallback onPressed;
  const _PulsingTomarButton({required this.pulsar, required this.onPressed});

  @override
  State<_PulsingTomarButton> createState() => _PulsingTomarButtonState();
}

class _PulsingTomarButtonState extends State<_PulsingTomarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  static const _teal = Color(0xFF44B4A6);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _animation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.pulsar) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PulsingTomarButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsar && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsar && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: widget.pulsar
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _teal.withValues(alpha: _animation.value * 0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                )
              : null,
          child: child,
        );
      },
      child: FilledButton.icon(
        onPressed: widget.onPressed,
        icon: const Icon(Icons.check, size: 16),
        label: const Text('Tomar'),
        style: FilledButton.styleFrom(
          backgroundColor: _teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
