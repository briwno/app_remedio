import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:postgres/postgres.dart';
import '../models/remedio.dart';
import '../models/registro.dart';
import '../models/notification_settings.dart';

class DatabaseService {
  static Connection? _connection;
  static bool _initialized = false;
  static const int _maxRetries = 3;

  static bool get isConnected => _connection != null && _initialized;

  static Future<Connection?> _getConnection() async {
    // Tenta reusar conexão existente com um teste rápido
    if (_connection != null) {
      try {
        await _connection!.execute('SELECT 1');
        return _connection;
      } catch (_) {
        debugPrint('DatabaseService: conexão perdida, reconectando...');
        _connection = null;
      }
    }

    // (Re)conectar com retries para redes móveis
    for (int tentativa = 1; tentativa <= _maxRetries; tentativa++) {
      try {
        _connection = await Connection.open(
          Endpoint(
            host: dotenv.env['DB_HOST']!,
            database: dotenv.env['DB_NAME']!,
            username: dotenv.env['DB_USER']!,
            password: dotenv.env['DB_PASSWORD']!,
          ),
          settings: ConnectionSettings(
            sslMode: SslMode.require,
            connectTimeout: const Duration(seconds: 20),
            queryTimeout: const Duration(seconds: 20),
          ),
        );
        debugPrint('DatabaseService: conectado ao Neon PostgreSQL (tentativa $tentativa)');
        return _connection;
      } catch (e) {
        debugPrint('DatabaseService: falha tentativa $tentativa/$_maxRetries: $e');
        _connection = null;
        if (tentativa < _maxRetries) {
          await Future.delayed(Duration(seconds: tentativa * 2));
        }
      }
    }
    debugPrint('DatabaseService: todas as tentativas falharam');
    return null;
  }

  /// Executa uma operação no banco com reconexão automática.
  /// Retorna null/valor padrão se falhar — nunca lança exceção.
  static Future<T> _executar<T>(
      T valorPadrao, Future<T> Function(Connection conn) operacao) async {
    try {
      final conn = await _getConnection();
      if (conn == null) return valorPadrao;
      return await operacao(conn);
    } catch (e) {
      debugPrint('DatabaseService: erro na query: $e');
      // Conexão pode ter sido invalidada, limpa para reconectar na próxima
      _connection = null;
      return valorPadrao;
    }
  }

  static Future<void> init() async {
    final conn = await _getConnection();
    if (conn == null) return;
    try {
      await _criarTabelas(conn);
      _initialized = true;
      debugPrint('DatabaseService: tabelas criadas/verificadas');
    } catch (e) {
      debugPrint('DatabaseService: erro ao criar tabelas: $e');
      _connection = null;
    }
  }

  static Future<void> _criarTabelas(Connection conn) async {
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS remedios (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        dosagem TEXT,
        horarios JSONB NOT NULL DEFAULT '[]',
        diario BOOLEAN NOT NULL DEFAULT true,
        ativo BOOLEAN NOT NULL DEFAULT true
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS registros (
        id SERIAL PRIMARY KEY,
        remedio_id TEXT NOT NULL,
        data_hora TIMESTAMPTZ NOT NULL,
        horario_previsto TEXT,
        UNIQUE(remedio_id, data_hora)
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS notification_settings (
        id INTEGER PRIMARY KEY DEFAULT 1,
        lembrete_antes BOOLEAN DEFAULT true,
        minutos_antes INTEGER DEFAULT 10,
        lembrete_na_hora BOOLEAN DEFAULT true,
        lembrete_depois BOOLEAN DEFAULT true,
        minutos_depois INTEGER DEFAULT 30
      )
    ''');

    await conn.execute('''
      CREATE TABLE IF NOT EXISTS mensagem_do_dia (
        id INTEGER PRIMARY KEY DEFAULT 1,
        mensagem TEXT NOT NULL DEFAULT 'Cuide-se bem, Nanay! 💜'
      )
    ''');

    // Garante que existe uma linha padrão
    await conn.execute('''
      INSERT INTO mensagem_do_dia (id, mensagem)
      VALUES (1, 'Cuide-se bem, Nanay! 💜')
      ON CONFLICT (id) DO NOTHING
    ''');
  }

  // --- Mensagem do Dia ---

  static Future<String?> carregarMensagemDoDia() async {
    return _executar<String?>(null, (conn) async {
      final result = await conn.execute(
        'SELECT mensagem FROM mensagem_do_dia WHERE id = 1',
      );
      if (result.isEmpty) return null;
      return result.first.toColumnMap()['mensagem'] as String?;
    });
  }

  // --- Remédios ---

  static Future<List<Remedio>> carregarRemedios() async {
    return _executar<List<Remedio>>([], (conn) async {
      final result = await conn.execute('SELECT * FROM remedios');
      return result.map((row) {
        final map = row.toColumnMap();
        return Remedio(
          id: map['id'] as String,
          nome: map['nome'] as String,
          dosagem: map['dosagem'] as String?,
          horarios: List<String>.from(map['horarios'] as List),
          diario: map['diario'] as bool,
          ativo: map['ativo'] as bool,
        );
      }).toList();
    });
  }

  static Future<void> salvarRemedio(Remedio remedio) async {
    await _executar(null, (conn) async {
      await conn.execute(
        Sql.named('''
          INSERT INTO remedios (id, nome, dosagem, horarios, diario, ativo)
          VALUES (@id, @nome, @dosagem, @horarios::jsonb, @diario, @ativo)
          ON CONFLICT (id) DO UPDATE SET
            nome = @nome,
            dosagem = @dosagem,
            horarios = @horarios::jsonb,
            diario = @diario,
            ativo = @ativo
        '''),
        parameters: {
          'id': remedio.id,
          'nome': remedio.nome,
          'dosagem': remedio.dosagem,
          'horarios': jsonEncode(remedio.horarios),
          'diario': remedio.diario,
          'ativo': remedio.ativo,
        },
      );
    });
  }

  static Future<void> removerRemedio(String id) async {
    await _executar(null, (conn) async {
      await conn.execute(
        Sql.named('DELETE FROM registros WHERE remedio_id = @id'),
        parameters: {'id': id},
      );
      await conn.execute(
        Sql.named('DELETE FROM remedios WHERE id = @id'),
        parameters: {'id': id},
      );
    });
  }

  // --- Registros ---

  static Future<List<Registro>> carregarRegistros() async {
    return _executar<List<Registro>>([], (conn) async {
      final result = await conn.execute('SELECT * FROM registros');
      return result.map((row) {
        final map = row.toColumnMap();
        return Registro(
          remedioId: map['remedio_id'] as String,
          dataHora: (map['data_hora'] as DateTime),
          horarioPrevisto: map['horario_previsto'] as String?,
        );
      }).toList();
    });
  }

  static Future<void> adicionarRegistro(Registro registro) async {
    await _executar(null, (conn) async {
      await conn.execute(
        Sql.named('''
          INSERT INTO registros (remedio_id, data_hora, horario_previsto)
          VALUES (@remedioId, @dataHora, @horarioPrevisto)
          ON CONFLICT DO NOTHING
        '''),
        parameters: {
          'remedioId': registro.remedioId,
          'dataHora': registro.dataHora,
          'horarioPrevisto': registro.horarioPrevisto,
        },
      );
    });
  }

  static Future<void> removerRegistro(
      String remedioId, DateTime data, String? horarioPrevisto) async {
    await _executar(null, (conn) async {
      final diaInicio = DateTime(data.year, data.month, data.day);
      final diaFim = diaInicio.add(const Duration(days: 1));

      if (horarioPrevisto != null) {
        await conn.execute(
          Sql.named('''
            DELETE FROM registros
            WHERE remedio_id = @remedioId
              AND data_hora >= @diaInicio
              AND data_hora < @diaFim
              AND horario_previsto = @horarioPrevisto
          '''),
          parameters: {
            'remedioId': remedioId,
            'diaInicio': diaInicio,
            'diaFim': diaFim,
            'horarioPrevisto': horarioPrevisto,
          },
        );
      } else {
        await conn.execute(
          Sql.named('''
            DELETE FROM registros
            WHERE remedio_id = @remedioId
              AND data_hora >= @diaInicio
              AND data_hora < @diaFim
              AND horario_previsto IS NULL
          '''),
          parameters: {
            'remedioId': remedioId,
            'diaInicio': diaInicio,
            'diaFim': diaFim,
          },
        );
      }
    });
  }

  static Future<void> removerRegistroEspecifico(Registro registro) async {
    await _executar(null, (conn) async {
      await conn.execute(
        Sql.named('''
          DELETE FROM registros
          WHERE remedio_id = @remedioId AND data_hora = @dataHora
        '''),
        parameters: {
          'remedioId': registro.remedioId,
          'dataHora': registro.dataHora,
        },
      );
    });
  }

  // --- Notification Settings ---

  static Future<NotificationSettings> carregarNotificationSettings() async {
    return _executar(const NotificationSettings(), (conn) async {
      final result = await conn
          .execute('SELECT * FROM notification_settings WHERE id = 1');
      if (result.isEmpty) return const NotificationSettings();
      final map = result.first.toColumnMap();
      return NotificationSettings(
        lembreteAntes: map['lembrete_antes'] as bool? ?? true,
        minutosAntes: map['minutos_antes'] as int? ?? 10,
        lembreteNaHora: map['lembrete_na_hora'] as bool? ?? true,
        lembreteDepois: map['lembrete_depois'] as bool? ?? true,
        minutosDepois: map['minutos_depois'] as int? ?? 30,
      );
    });
  }

  static Future<void> salvarNotificationSettings(
      NotificationSettings settings) async {
    await _executar(null, (conn) async {
      await conn.execute(
        Sql.named('''
          INSERT INTO notification_settings
            (id, lembrete_antes, minutos_antes, lembrete_na_hora, lembrete_depois, minutos_depois)
          VALUES (1, @lembreteAntes, @minutosAntes, @lembreteNaHora, @lembreteDepois, @minutosDepois)
          ON CONFLICT (id) DO UPDATE SET
            lembrete_antes = @lembreteAntes,
            minutos_antes = @minutosAntes,
            lembrete_na_hora = @lembreteNaHora,
            lembrete_depois = @lembreteDepois,
            minutos_depois = @minutosDepois
        '''),
        parameters: {
          'lembreteAntes': settings.lembreteAntes,
          'minutosAntes': settings.minutosAntes,
          'lembreteNaHora': settings.lembreteNaHora,
          'lembreteDepois': settings.lembreteDepois,
          'minutosDepois': settings.minutosDepois,
        },
      );
    });
  }
}
