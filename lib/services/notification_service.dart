import 'dart:developer' as dev;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/remedio.dart';
import '../models/registro.dart';
import '../models/notification_settings.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _androidDetails = AndroidNotificationDetails(
    'remedios_channel',
    'Remédios da Nanay',
    channelDescription: 'Lembretes de remédios da Nanay',
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
    final timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    dev.log('NotificationService: timezone = $timeZoneName');

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
      List<Registro> registrosHoje = const [],
  }) async {
    await _plugin.cancelAll();
    final agora = DateTime.now();
    final tomadasHojePorHorario = registrosHoje
      .where((registro) =>
        registro.horarioPrevisto != null &&
        _mesmoDia(registro.dataHora, agora))
      .map((registro) => '${registro.remedioId}|${registro.horarioPrevisto}')
      .toSet();

    int notifId = 0;
    for (final remedio in remedios) {
      if (!remedio.ativo || !remedio.diario) continue;

      for (final horario in remedio.horarios) {
        final partes = horario.split(':');
        final hora = int.parse(partes[0]);
        final minuto = int.parse(partes[1]);
        final tomouHojeNoHorario =
          tomadasHojePorHorario.contains('${remedio.id}|$horario');

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
            titulo: '⏰ Nanay, ${remedio.nome} em breve!',
            corpo: 'Em $min minutos é hora de tomar ${remedio.nome} 💜',
            hora: horaAntes,
            minuto: minAntes,
          );
        }

        // Notificação "Hora de tomar"
        if (settings.lembreteNaHora) {
          await _agendarDiaria(
            id: notifId++,
            titulo: '💊 Nanay, REMEDIUUUUUUUUUU - ${remedio.nome}!',
            corpo: 'Nanay, tome seu ${remedio.nome} agora'
                '${remedio.dosagem != null ? ' - ${remedio.dosagem}' : ''} 💜',
            hora: hora,
            minuto: minuto,
          );
        }

        // Notificação "Esqueceu?" - X min depois (configurável)
        if (settings.lembreteDepois) {
          final min = settings.minutosDepois;
          int minDepois = minuto + min;
          int horaDepois = hora;
          var pularProximaOcorrencia = false;
          if (tomouHojeNoHorario) {
            final horarioEsqueceuHoje =
                DateTime(agora.year, agora.month, agora.day, hora, minuto)
                    .add(Duration(minutes: min));
            pularProximaOcorrencia = agora.isBefore(horarioEsqueceuHoje);
          }
          while (minDepois >= 60) {
            minDepois -= 60;
            horaDepois += 1;
          }
          await _agendarDiaria(
            id: notifId++,
            titulo: '⚠️ Nanay, esqueceu o ${remedio.nome}?',
            corpo:
                'Nanay, já faz $min minutos do horário de ${remedio.nome}. Não esqueça! 💜',
            hora: horaDepois,
            minuto: minDepois,
            pularProximaOcorrencia: pularProximaOcorrencia,
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
      title: '🧪 Teste - Remédios da Nanay',
      body: 'Nanay, as notificações estão funcionando! 💜',
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
    bool pularProximaOcorrencia = false,
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

    if (pularProximaOcorrencia) {
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

  static bool _mesmoDia(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }
}
