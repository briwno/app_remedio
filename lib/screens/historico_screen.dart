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

  static const _teal = Color(0xFF44B4A6);
  static const _accent = Color(0xFF9C7CDB);
  static const _warmBg = Color(0xFFF0EBE3);
  static const _darkText = Color(0xFF2D2D2D);

  @override
  void initState() {
    super.initState();
    final agora = DateTime.now();
    _mesSelecionado = DateTime(agora.year, agora.month);
    widget.storage.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.storage.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
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
      backgroundColor: _warmBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Histórico\nda Nanay',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLegenda(),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildCalendario(),
            ),
          ),
          if (_diaSelecionado != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _legendaItem(Colors.green, 'Tudo tomado'),
        const SizedBox(width: 16),
        _legendaItem(_accent, 'Parcial'),
        const SizedBox(width: 16),
        _legendaItem(const Color(0xFFE57373), 'Nenhum'),
      ],
    );
  }

  Widget _legendaItem(Color cor, String texto) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(texto,
            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildCalendario() {
    final mesNome = DateFormat('MMMM yyyy', 'pt_BR').format(_mesSelecionado);
    final primeiroDia = DateTime(_mesSelecionado.year, _mesSelecionado.month, 1);
    final ultimoDia =
        DateTime(_mesSelecionado.year, _mesSelecionado.month + 1, 0);
    final diasNoMes = ultimoDia.day;
    final diaDaSemanaInicio = (primeiroDia.weekday - 1) % 7;
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);

    return Container(
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
          children: [
            // Navegação do mês
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: _darkText,
                  onPressed: () => _mudarMes(-1),
                ),
                Text(
                  mesNome[0].toUpperCase() + mesNome.substring(1),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: _darkText,
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
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500])),
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
                        return const Expanded(child: SizedBox(height: 42));
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
                      final ehHoje = dia.year == hoje.year &&
                          dia.month == hoje.month &&
                          dia.day == hoje.day;
                      final status = ehFuturo ? 'sem_dados' : _statusDoDia(dia);

                      Color? bgColor;
                      if (status == 'completo') {
                        bgColor = Colors.green;
                      } else if (status == 'parcial') {
                        bgColor = _accent;
                      } else if (status == 'nenhum') {
                        bgColor = const Color(0xFFE57373);
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: ehFuturo
                              ? null
                              : () => setState(() => _diaSelecionado = dia),
                          child: Container(
                            height: 42,
                            margin: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: ehSelecionado
                                  ? _teal.withValues(alpha: 0.15)
                                  : bgColor?.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: ehSelecionado
                                  ? Border.all(color: _teal, width: 2)
                                  : ehHoje
                                      ? Border.all(color: _accent, width: 1.5)
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
                                      fontWeight: ehSelecionado || ehHoje
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: ehFuturo
                                          ? Colors.grey[350]
                                          : _darkText,
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

    return Container(
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
            Text(
              'Detalhes - $dataFormatada',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _darkText,
              ),
            ),
            Divider(color: Colors.grey[200]),
            if (registros.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Nenhum remédio registrado neste dia',
                    style: TextStyle(color: Colors.grey[500]),
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
          const Icon(Icons.medication_rounded, size: 20, color: _teal),
          const SizedBox(width: 8),
          Expanded(
            child: Text(remedio.nome,
                style: const TextStyle(fontWeight: FontWeight.w500, color: _darkText)),
          ),
          ...remedio.horarios.map((h) {
            final tomado = widget.storage.foiTomado(remedio.id, dia, h);
            return Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tomado
                    ? _teal.withValues(alpha: 0.15)
                    : const Color(0xFFE57373).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tomado ? Icons.check : Icons.close,
                    size: 14,
                    color: tomado ? _teal : const Color(0xFFE57373),
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
          const Icon(Icons.medical_services_rounded,
              size: 20, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(remedio.nome,
                style: const TextStyle(fontWeight: FontWeight.w500, color: _darkText)),
          ),
          Text(
            '${registros.length}x',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _accent),
          ),
        ],
      ),
    );
  }
}
