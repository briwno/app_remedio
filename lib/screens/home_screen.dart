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
  }

  void _atualizarRemedios() {
    setState(() {
      _remedios = widget.storage.carregarRemedios();
    });
  }

  void _irParaDia(int delta) {
    setState(() {
      _diaSelecionado = _diaSelecionado.add(Duration(days: delta));
    });
  }

  Future<void> _toggleRemedio(Remedio remedio, String? horario) async {
    final tomado = widget.storage.foiTomado(remedio.id, _diaLimpo, horario);
    if (tomado) {
      // Confirmar antes de desmarcar
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
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
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Desmarcar'),
            ),
          ],
        ),
      );
      if (confirmar == true) {
        await widget.storage.removerRegistro(remedio.id, _diaLimpo, horario);
        setState(() {});
      }
    } else {
      await widget.storage.registrarTomado(Registro(
        remedioId: remedio.id,
        dataHora: DateTime.now(),
        horarioPrevisto: horario,
      ));
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('${remedio.nome} marcado às ${horario ?? DateFormat('HH:mm').format(DateTime.now())}'),
              ],
            ),
            backgroundColor: Colors.green,
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
          backgroundColor: Colors.green,
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
      agora.year,
      agora.month,
      agora.day,
      int.parse(partes[0]),
      int.parse(partes[1]),
    );

    final diff = horaRemedio.difference(agora).inMinutes;
    if (diff > 15) return 'agendado';
    if (diff > 0) return 'em_breve';
    if (diff > -30) return 'atrasado';
    return 'perdido';
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'tomado':
        return Colors.green;
      case 'em_breve':
        return Colors.orange;
      case 'atrasado':
        return Colors.red;
      case 'perdido':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _iconeStatus(String status) {
    switch (status) {
      case 'tomado':
        return Icons.check_circle;
      case 'em_breve':
        return Icons.access_time;
      case 'atrasado':
        return Icons.warning_amber_rounded;
      case 'perdido':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule;
    }
  }

  String _textoStatus(String status) {
    switch (status) {
      case 'tomado':
        return 'Tomado ✓';
      case 'em_breve':
        return 'Em breve';
      case 'atrasado':
        return 'Atrasado!';
      case 'perdido':
        return 'Não tomou';
      default:
        return 'Agendado';
    }
  }

  @override
  Widget build(BuildContext context) {
    final diarios = _remedios.where((r) => r.diario && r.ativo).toList();
    final sos = _remedios.where((r) => !r.diario && r.ativo).toList();
    final registrosSOS = widget.storage.registrosDoDia(_diaLimpo);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FF),
      body: RefreshIndicator(
        onRefresh: () async => _atualizarRemedios(),
        child: CustomScrollView(
          slivers: [
            // Header com data
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
                child: Column(
                  children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '💊 Nanay Remédios',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_active_outlined,
                            color: Colors.white),
                        onPressed: () {
                          NotificationService.enviarNotificacaoTeste();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('📬 Notificação de teste enviada!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: Colors.white),
                          onPressed: () => _irParaDia(-1),
                        ),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _ehHoje
                                  ? 'Hoje - ${_dateFormat.format(_diaSelecionado)}'
                                  : _dateFormat.format(_diaSelecionado),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right,
                              color: Colors.white),
                          onPressed: _ehHoje ? null : () => _irParaDia(1),
                        ),
                      ],
                    ),
                    if (_ehHoje) ...[
                      const SizedBox(height: 12),
                      _buildResumoHoje(diarios),
                    ],
                  ],
                ),
              ),
            ),

            // Remédios diários
            if (diarios.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    '📅 Remédios Diários',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A148C),
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildRemedioDiarioCard(diarios[index]),
                  childCount: diarios.length,
                ),
              ),
            ],

            // Remédios SOS
            if (sos.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                  child: Text(
                    '🆘 Quando Precisar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A148C),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: progresso,
              backgroundColor: Colors.white.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              strokeWidth: 4,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$tomados/$total tomados hoje',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemedioDiarioCard(Remedio remedio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8DEF8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medication,
                        color: Color(0xFF7C4DFF), size: 24),
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (remedio.dosagem != null)
                          Text(
                            remedio.dosagem!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleRemedio(remedio, horario),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: tomado
                  ? Colors.green.withValues(alpha: 0.15)
                  : cor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tomado
                    ? Colors.green
                    : cor.withValues(alpha: 0.4),
                width: tomado ? 2 : 1.5,
              ),
              boxShadow: tomado
                  ? [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tomado
                        ? Colors.green.withValues(alpha: 0.2)
                        : cor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _iconeStatus(status),
                    color: tomado ? Colors.green : cor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  horario,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: tomado ? Colors.green : cor,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tomado
                        ? Colors.green
                        : cor.withValues(alpha: 0.2),
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
    );
  }

  Widget _buildRemedioSOSCard(Remedio remedio, List<Registro> registros) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medical_services,
                        color: Colors.orange, size: 24),
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
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          remedio.dosagem ?? 'Usar quando precisar',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_ehHoje)
                    ElevatedButton.icon(
                      onPressed: () => _registrarSOS(remedio),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tomar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C4DFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                ],
              ),
              if (registros.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.history, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      'Registros neste dia (${registros.length}x):',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
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
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle,
            color: Colors.green,
            size: 18,
          ),
        ),
        title: Text(
          descricao,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: _ehHoje
            ? Text(
                'Toque para desmarcar',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              )
            : null,
        trailing: _ehHoje
            ? IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.red,
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
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.orange),
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
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
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
