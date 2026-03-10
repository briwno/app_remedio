import 'dart:developer' as dev;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/remedio.dart';
import '../models/notification_settings.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _androidDetails = AndroidNotificationDetails(
    'remedios_channel',
    'Lembretes de Remédios',
    channelDescription: 'Notificações para lembrar de tomar remédios',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
  );

  static const _notificationDetails = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  static Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  static Future<void> agendarNotificacoesRemedios(
      List<Remedio> remedios, {
      NotificationSettings settings = const NotificationSettings(),
  }) async {
    await _plugin.cancelAll();

    int notifId = 0;
    for (final remedio in remedios) {
      if (!remedio.ativo || !remedio.diario) continue;

      for (final horario in remedio.horarios) {
        final partes = horario.split(':');
        final hora = int.parse(partes[0]);
        final minuto = int.parse(partes[1]);

        // Notificação "Em breve" - X min antes (configurável)
        if (settings.lembreteAntes) {
          final min = settings.minutosAntes;
          int minAntes = minuto - min;
          int horaAntes = hora;
          while (minAntes < 0) {
            minAntes += 60;
            horaAntes -= 1;
          }
          await _agendarDiaria(
            id: notifId++,
            titulo: '⏰ ${remedio.nome} em breve',
            corpo: 'Em $min minutos é hora de tomar ${remedio.nome}',
            hora: horaAntes,
            minuto: minAntes,
          );
        }

        // Notificação "Hora de tomar"
        if (settings.lembreteNaHora) {
          await _agendarDiaria(
            id: notifId++,
            titulo: '💊 Hora do ${remedio.nome}!',
            corpo: 'Tome seu ${remedio.nome} agora'
                '${remedio.dosagem != null ? ' - ${remedio.dosagem}' : ''}',
            hora: hora,
            minuto: minuto,
          );
        }

        // Notificação "Esqueceu?" - X min depois (configurável)
        if (settings.lembreteDepois) {
          final min = settings.minutosDepois;
          int minDepois = minuto + min;
          int horaDepois = hora;
          while (minDepois >= 60) {
            minDepois -= 60;
            horaDepois += 1;
          }
          await _agendarDiaria(
            id: notifId++,
            titulo: '⚠️ Esqueceu o ${remedio.nome}?',
            corpo:
                'Já faz $min minutos do horário de ${remedio.nome}. Não esqueça!',
            hora: horaDepois,
            minuto: minDepois,
          );
        }
      }
    }

    // Log de verificação
    final pendentes = await _plugin.pendingNotificationRequests();
    dev.log('NotificationService: ${pendentes.length} notificações agendadas');
    for (final p in pendentes) {
      dev.log('  → id=${p.id} title="${p.title}"');
    }
  }

  static Future<void> enviarNotificacaoTeste() async {
    await _plugin.show(
      id: 9999,
      title: '🧪 Notificação de Teste',
      body: 'Sistema de notificações funcionando corretamente!',
      notificationDetails: _notificationDetails,
    );
  }

  /// Agenda uma notificação para daqui a 5 segundos via AlarmManager.
  /// Funciona mesmo se o app for fechado.
  static Future<void> agendarNotificacaoEm5Segundos() async {
    final agendado = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));

    await _plugin.zonedSchedule(
      id: 9998,
      title: '🔔 Teste agendado!',
      body: 'Esta notificação foi agendada 5 segundos atrás. Funcionou!',
      scheduledDate: agendado,
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> _agendarDiaria({
    required int id,
    required String titulo,
    required String corpo,
    required int hora,
    required int minuto,
  }) async {
    final horaFinal = hora % 24;
    final minutoFinal = minuto % 60;

    final agora = tz.TZDateTime.now(tz.local);
    var agendado = tz.TZDateTime(
      tz.local,
      agora.year,
      agora.month,
      agora.day,
      horaFinal,
      minutoFinal,
    );

    if (agendado.isBefore(agora)) {
      agendado = agendado.add(const Duration(days: 1));
    }

    dev.log('Agendando "$titulo" para $agendado (id=$id)');

    await _plugin.zonedSchedule(
      id: id,
      title: titulo,
      body: corpo,
      scheduledDate: agendado,
      notificationDetails: _notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
