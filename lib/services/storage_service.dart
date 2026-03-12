import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/remedio.dart';
import '../models/registro.dart';
import '../models/notification_settings.dart';
import 'database_service.dart';

class StorageService extends ChangeNotifier {
  static const _remediosKey = 'remedios';
  static const _registrosKey = 'registros';
  static const _inicializadoKey = 'inicializado';
  static const _notifSettingsKey = 'notification_settings';

  late SharedPreferences _prefs;
  String _mensagemDoDia = '';

  String get mensagemDoDia => _mensagemDoDia;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Conectar ao banco de dados online
    await DatabaseService.init();

    if (DatabaseService.isConnected) {
      await _sincronizarComBanco();
      await atualizarMensagemDoDia();
    } else if (!(_prefs.getBool(_inicializadoKey) ?? false)) {
      await _criarRemediosPadrao();
      await _prefs.setBool(_inicializadoKey, true);
    }
  }

  /// Sincroniza dados entre o banco online e o cache local.
  /// Se o banco tem dados, usa eles (fonte da verdade).
  /// Se o banco está vazio e tem dados locais, envia para o banco.
  Future<void> _sincronizarComBanco() async {
    try {
      // --- Remédios ---
      final remediosDb = await DatabaseService.carregarRemedios();
      final remediosLocal = carregarRemedios();

      if (remediosDb.isNotEmpty) {
        // Banco tem dados → atualiza cache local
        await _salvarRemediosLocal(remediosDb);
        dev.log('Sync: ${remediosDb.length} remédios baixados do banco');
      } else if (remediosLocal.isNotEmpty) {
        // Banco vazio, local tem dados → envia para o banco
        for (final r in remediosLocal) {
          await DatabaseService.salvarRemedio(r);
        }
        dev.log('Sync: ${remediosLocal.length} remédios enviados ao banco');
      } else {
        // Ambos vazios → criar padrão e salvar em ambos
        await _criarRemediosPadrao();
        final padrao = carregarRemedios();
        for (final r in padrao) {
          await DatabaseService.salvarRemedio(r);
        }
      }

      // --- Registros ---
      final registrosDb = await DatabaseService.carregarRegistros();
      final registrosLocal = carregarRegistros();

      if (registrosDb.isNotEmpty) {
        await _salvarRegistrosLocal(registrosDb);
        dev.log('Sync: ${registrosDb.length} registros baixados do banco');
      } else if (registrosLocal.isNotEmpty) {
        for (final r in registrosLocal) {
          await DatabaseService.adicionarRegistro(r);
        }
        dev.log('Sync: ${registrosLocal.length} registros enviados ao banco');
      }

      // --- Notification Settings ---
      final settingsDb = await DatabaseService.carregarNotificationSettings();
      final settingsLocal = carregarNotificationSettings();
      final defaultSettings = const NotificationSettings();

      // Se o banco tem configuração personalizada, usa ela
      if (settingsDb.minutosAntes != defaultSettings.minutosAntes ||
          settingsDb.minutosDepois != defaultSettings.minutosDepois ||
          settingsDb.lembreteAntes != defaultSettings.lembreteAntes ||
          settingsDb.lembreteNaHora != defaultSettings.lembreteNaHora ||
          settingsDb.lembreteDepois != defaultSettings.lembreteDepois) {
        await _salvarNotificationSettingsLocal(settingsDb);
      } else if (settingsLocal.minutosAntes != defaultSettings.minutosAntes ||
          settingsLocal.minutosDepois != defaultSettings.minutosDepois) {
        await DatabaseService.salvarNotificationSettings(settingsLocal);
      }

      await _prefs.setBool(_inicializadoKey, true);
      dev.log('Sync: sincronização concluída');
    } catch (e) {
      dev.log('Sync: erro na sincronização: $e');
    }
  }

  Future<void> atualizarMensagemDoDia() async {
    final msg = await DatabaseService.carregarMensagemDoDia();
    if (msg != null && msg != _mensagemDoDia) {
      _mensagemDoDia = msg;
      notifyListeners();
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
    await _salvarRemediosLocal(remediosPadrao);
  }

  // ==========================================
  // Remédios
  // ==========================================

  List<Remedio> carregarRemedios() {
    final json = _prefs.getString(_remediosKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => Remedio.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _salvarRemediosLocal(List<Remedio> remedios) async {
    final json = jsonEncode(remedios.map((e) => e.toJson()).toList());
    await _prefs.setString(_remediosKey, json);
  }

  Future<void> salvarRemedios(List<Remedio> remedios) async {
    await _salvarRemediosLocal(remedios);
    notifyListeners();
    if (DatabaseService.isConnected) {
      for (final r in remedios) {
        await DatabaseService.salvarRemedio(r);
      }
    }
  }

  Future<void> adicionarRemedio(Remedio remedio) async {
    final lista = carregarRemedios();
    lista.add(remedio);
    await _salvarRemediosLocal(lista);
    notifyListeners();
    if (DatabaseService.isConnected) {
      await DatabaseService.salvarRemedio(remedio);
    }
  }

  Future<void> atualizarRemedio(Remedio remedio) async {
    final lista = carregarRemedios();
    final index = lista.indexWhere((r) => r.id == remedio.id);
    if (index >= 0) {
      lista[index] = remedio;
      await _salvarRemediosLocal(lista);
      notifyListeners();
      if (DatabaseService.isConnected) {
        await DatabaseService.salvarRemedio(remedio);
      }
    }
  }

  Future<void> removerRemedio(String id) async {
    final lista = carregarRemedios();
    lista.removeWhere((r) => r.id == id);
    await _salvarRemediosLocal(lista);

    final registros = carregarRegistros();
    registros.removeWhere((r) => r.remedioId == id);
    await _salvarRegistrosLocal(registros);

    notifyListeners();
    if (DatabaseService.isConnected) {
      await DatabaseService.removerRemedio(id);
    }
  }

  // ==========================================
  // Registros
  // ==========================================

  List<Registro> carregarRegistros() {
    final json = _prefs.getString(_registrosKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => Registro.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _salvarRegistrosLocal(List<Registro> registros) async {
    final json = jsonEncode(registros.map((e) => e.toJson()).toList());
    await _prefs.setString(_registrosKey, json);
  }

  Future<void> registrarTomado(Registro registro) async {
    final lista = carregarRegistros();
    lista.add(registro);
    await _salvarRegistrosLocal(lista);
    notifyListeners();
    if (DatabaseService.isConnected) {
      await DatabaseService.adicionarRegistro(registro);
    }
  }

  Future<void> removerRegistro(
      String remedioId, DateTime data, String? horarioPrevisto) async {
    final lista = carregarRegistros();
    lista.removeWhere((r) =>
        r.remedioId == remedioId &&
        r.data == DateTime(data.year, data.month, data.day) &&
        r.horarioPrevisto == horarioPrevisto);
    await _salvarRegistrosLocal(lista);
    if (DatabaseService.isConnected) {
      await DatabaseService.removerRegistro(remedioId, data, horarioPrevisto);
    }
    notifyListeners();
  }

  Future<void> removerRegistroEspecifico(Registro registro) async {
    final lista = carregarRegistros();
    lista.removeWhere((r) =>
        r.remedioId == registro.remedioId &&
        r.dataHora.isAtSameMomentAs(registro.dataHora));
    await _salvarRegistrosLocal(lista);
    if (DatabaseService.isConnected) {
      await DatabaseService.removerRegistroEspecifico(registro);
    }
    notifyListeners();
  }

  List<Registro> registrosDoDia(DateTime dia) {
    final diaLimpo = DateTime(dia.year, dia.month, dia.day);
    return carregarRegistros().where((r) => r.data == diaLimpo).toList();
  }

  bool foiTomado(String remedioId, DateTime dia, String? horarioPrevisto) {
    final registros = registrosDoDia(dia);
    return registros.any((r) =>
        r.remedioId == remedioId && r.horarioPrevisto == horarioPrevisto);
  }

  // ==========================================
  // Configurações de Notificação
  // ==========================================

  NotificationSettings carregarNotificationSettings() {
    final json = _prefs.getString(_notifSettingsKey);
    if (json == null) return const NotificationSettings();
    return NotificationSettings.fromJson(
        jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> _salvarNotificationSettingsLocal(
      NotificationSettings settings) async {
    final json = jsonEncode(settings.toJson());
    await _prefs.setString(_notifSettingsKey, json);
  }

  Future<void> salvarNotificationSettings(
      NotificationSettings settings) async {
    await _salvarNotificationSettingsLocal(settings);
    notifyListeners();
    if (DatabaseService.isConnected) {
      await DatabaseService.salvarNotificationSettings(settings);
    }
  }
}