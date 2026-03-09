import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/remedio.dart';
import '../services/storage_service.dart';

class HistoricoScreen extends StatefulWidget {
  final StorageService storage;
  const HistoricoScreen({super.key, required this.storage});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  late DateTime _mesSelecionado;
  DateTime? _diaSelecionado;

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mesSelecionado = DateTime(agora.year, agora.month);
  }

  void _mudarMes(int delta) {
    setState(() {
      _mesSelecionado = DateTime(
        _mesSelecionado.year,
        _mesSelecionado.month + delta,
      );
      _diaSelecionado = null;
    });
  }

  /// Retorna o status de um dia: 'completo', 'parcial', 'nenhum', 'sem_dados'
  String _statusDoDia(DateTime dia) {
    final remedios = widget.storage
        .carregarRemedios()
        .where((r) => r.diario && r.ativo)
        .toList();
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
              child: Column(
                children: [
                  const Text(
                    '📊 Histórico',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLegenda(),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildCalendario(),
            ),
          ),
          if (_diaSelecionado != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildDetalhesDia(_diaSelecionado!),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildLegenda() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendaItem(Colors.green, 'Tudo tomado'),
        const SizedBox(width: 16),
        _legendaItem(Colors.orange, 'Parcial'),
        const SizedBox(width: 16),
        _legendaItem(Colors.red, 'Nenhum'),
      ],
    );
  }

  Widget _legendaItem(Color cor, String texto) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(texto,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildCalendario() {
    final mesNome = DateFormat('MMMM yyyy', 'pt_BR').format(_mesSelecionado);
    final primeiroDia = DateTime(_mesSelecionado.year, _mesSelecionado.month, 1);
    final ultimoDia =
        DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0);
    final diasNoMes = ultimoDia.day;
    // segunda = 1, domingo = 7; ajustar para começar na segunda
    final diaDaSemanaInicio = (primeiroDia.weekday - 1) % 7;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Navegação do mês
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _mudarMes(-1),
                ),
                Text(
                  mesNome[0].toUpperCase() + mesNome.substring(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A148C),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _mesSelecionado.month >= agora.month &&
                          _mesSelecionado.year >= agora.year
                      ? null
                      : () => _mudarMes(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Cabeçalho dias da semana
            Row(
              children: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom']
                  .map((d) => Expanded(
                        child: Center(
                          child: Text(d,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600])),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Grid de dias
            ...List.generate(
              ((diasNoMes + diaDaSemanaInicio) / 7).ceil(),
              (semana) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: List.generate(7, (diaSemana) {
                      final diaIndex =
                          semana * 7 + diaSemana - diaDaSemanaInicio + 1;
                      if (diaIndex < 1 || diaIndex > diasNoMes) {
                        return const Expanded(child: SizedBox(height: 40));
                      }

                      final dia = DateTime(
                        _mesSelecionado.year,
                        _mesSelecionado.month,
                        diaIndex,
                      );
                      final ehFuturo = dia.isAfter(hoje);
                      final ehSelecionado = _diaSelecionado != null &&
                          _diaSelecionado!.year == dia.year &&
                          _diaSelecionado!.month == dia.month &&
                          _diaSelecionado!.day == dia.day;
                      final status = ehFuturo ? 'sem_dados' : _statusDoDia(dia);

                      Color? bgColor;
                      if (status == 'completo') {
                        bgColor = Colors.green;
                      } else if (status == 'parcial') {
                        bgColor = Colors.orange;
                      } else if (status == 'nenhum') {
                        bgColor = Colors.red;
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: ehFuturo
                              ? null
                              : () =>
                                  setState(() => _diaSelecionado = dia),
                          child: Container(
                            height: 40,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: bgColor?.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: ehSelecionado
                                  ? Border.all(
                                      color: const Color(0xFF7C4DFF),
                                      width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$diaIndex',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: ehSelecionado
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: ehFuturo
                                          ? Colors.grey[400]
                                          : Colors.black87,
                                    ),
                                  ),
                                  if (bgColor != null)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: bgColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalhesDia(DateTime dia) {
    final remedios = widget.storage.carregarRemedios();
    final registros = widget.storage.registrosDoDia(dia);
    final dataFormatada = DateFormat('d MMMM yyyy', 'pt_BR').format(dia);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalhes - $dataFormatada',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A148C),
              ),
            ),
            const Divider(),
            if (registros.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Nenhum remédio registrado neste dia',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...remedios.map((remedio) {
                final regs =
                    registros.where((r) => r.remedioId == remedio.id).toList();
                if (remedio.diario) {
                  return _buildDetalheDiario(remedio, dia);
                } else if (regs.isNotEmpty) {
                  return _buildDetalheSOS(remedio, regs);
                }
                return const SizedBox.shrink();
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalheDiario(Remedio remedio, DateTime dia) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.medication, size: 20, color: Color(0xFF7C4DFF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(remedio.nome,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          ...remedio.horarios.map((h) {
            final tomado = widget.storage.foiTomado(remedio.id, dia, h);
            return Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tomado
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tomado ? Icons.check : Icons.close,
                    size: 14,
                    color: tomado ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 4),
                  Text(h, style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetalheSOS(Remedio remedio, List registros) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.medical_services,
              size: 20, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(remedio.nome,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Text(
            '${registros.length}x',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.orange),
          ),
        ],
      ),
    );
  }
}
