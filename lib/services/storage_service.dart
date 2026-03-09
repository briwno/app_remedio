import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/remedio.dart';
import '../models/registro.dart';

class StorageService {
  static const _remediosKey = 'remedios';
  static const _registrosKey = 'registros';
  static const _inicializadoKey = 'inicializado';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (!(_prefs.getBool(_inicializadoKey) ?? false)) {
      await _criarRemediosPadrao();
      await _prefs.setBool(_inicializadoKey, true);
    }
  }

  Future<void> _criarRemediosPadrao() async {
    final remediosPadrao = [
      Remedio(
        id: 'anticoncepcional',
        nome: 'Anticoncepcional',
        horarios: ['12:00'],
        diario: true,
      ),
      Remedio(
        id: 'quetiapina',
        nome: 'Quetiapina',
        horarios: ['22:00'],
        diario: true,
      ),
      Remedio(
        id: 'alprazolam',
        nome: 'Alprazolam',
        dosagem: 'Quando precisar',
        horarios: [],
        diario: false,
      ),
    ];
    await salvarRemedios(remediosPadrao);
  }

  // --- Remédios ---

  List<Remedio> carregarRemedios() {
    final json = _prefs.getString(_remediosKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => Remedio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> salvarRemedios(List<Remedio> remedios) async {
    final json = jsonEncode(remedios.map((e) => e.toJson()).toList());
    await _prefs.setString(_remediosKey, json);
  }

  Future<void> adicionarRemedio(Remedio remedio) async {
    final lista = carregarRemedios();
    lista.add(remedio);
    await salvarRemedios(lista);
  }

  Future<void> atualizarRemedio(Remedio remedio) async {
    final lista = carregarRemedios();
    final index = lista.indexWhere((r) => r.id == remedio.id);
    if (index >= 0) {
      lista[index] = remedio;
      await salvarRemedios(lista);
    }
  }

  Future<void> removerRemedio(String id) async {
    final lista = carregarRemedios();
    lista.removeWhere((r) => r.id == id);
    await salvarRemedios(lista);
    // Remover registros associados
    final registros = carregarRegistros();
    registros.removeWhere((r) => r.remedioId == id);
    await _salvarRegistros(registros);
  }

  // --- Registros ---

  List<Registro> carregarRegistros() {
    final json = _prefs.getString(_registrosKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => Registro.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _salvarRegistros(List<Registro> registros) async {
    final json = jsonEncode(registros.map((e) => e.toJson()).toList());
    await _prefs.setString(_registrosKey, json);
  }

  Future<void> registrarTomado(Registro registro) async {
    final lista = carregarRegistros();
    lista.add(registro);
    await _salvarRegistros(lista);
  }

  Future<void> removerRegistro(String remedioId, DateTime data,
      String? horarioPrevisto) async {
    final lista = carregarRegistros();
    lista.removeWhere((r) =>
        r.remedioId == remedioId &&
        r.data == DateTime(data.year, data.month, data.day) &&
        r.horarioPrevisto == horarioPrevisto);
    await _salvarRegistros(lista);
  }

  /// Remove um registro específico baseado no objeto completo
  Future<void> removerRegistroEspecifico(Registro registro) async {
    final lista = carregarRegistros();
    lista.removeWhere((r) =>
        r.remedioId == registro.remedioId &&
        r.dataHora.isAtSameMomentAs(registro.dataHora));
    await _salvarRegistros(lista);
  }

  /// Registros de um dia específico
  List<Registro> registrosDoDia(DateTime dia) {
    final diaLimpo = DateTime(dia.year, dia.month, dia.day);
    return carregarRegistros().where((r) => r.data == diaLimpo).toList();
  }

  /// Verifica se um remédio+horário foi tomado em um dia
  bool foiTomado(String remedioId, DateTime dia, String? horarioPrevisto) {
    final registros = registrosDoDia(dia);
    return registros.any((r) =>
        r.remedioId == remedioId && r.horarioPrevisto == horarioPrevisto);
  }

  /// Retorna todas as datas que têm pelo menos um registro
  Set<DateTime> diasComRegistro() {
    return carregarRegistros().map((r) => r.data).toSet();
  }
}
