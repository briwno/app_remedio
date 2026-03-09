import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/remedio.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

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

    await _plugin.initialize(settings);

    // Solicitar permissão no Android 13+
    _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> agendarNotificacoesRemedios(
      List<Remedio> remedios) async {
    await _plugin.cancelAll();

    int notifId = 0;
    for (final remedio in remedios) {
      if (!remedio.ativo || !remedio.diario) continue;

      for (final horario in remedio.horarios) {
        final partes = horario.split(':');
        final hora = int.parse(partes[0]);
        final minuto = int.parse(partes[1]);

        // Notificação "Em breve" - 15 min antes
        await _agendarDiaria(
          id: notifId++,
          titulo: '⏰ ${remedio.nome} em breve',
          corpo: 'Em 15 minutos é hora de tomar ${remedio.nome}',
          hora: hora,
          minuto: minuto - 15 < 0 ? minuto + 45 : minuto - 15,
          horaAjuste: minuto - 15 < 0 ? hora - 1 : hora,
        );

        // Notificação "Hora de tomar"
        await _agendarDiaria(
          id: notifId++,
          titulo: '💊 Hora do ${remedio.nome}!',
          corpo: 'Tome seu ${remedio.nome} agora'
              '${remedio.dosagem != null ? ' - ${remedio.dosagem}' : ''}',
          hora: hora,
          minuto: minuto,
        );

        // Notificação "Esqueceu?" - 30 min depois
        await _agendarDiaria(
          id: notifId++,
          titulo: '⚠️ Esqueceu o ${remedio.nome}?',
          corpo:
              'Já faz 30 minutos do horário de ${remedio.nome}. Não esqueça!',
          hora: hora,
          minuto: minuto + 30 >= 60 ? minuto - 30 : minuto + 30,
          horaAjuste: minuto + 30 >= 60 ? hora + 1 : hora,
        );
      }
    }
  }

  static Future<void> enviarNotificacaoTeste() async {
    await _plugin.show(
      9999,
      '🧪 Notificação de Teste',
      'Sistema de notificações funcionando corretamente!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'remedios_channel',
          'Lembretes de Remédios',
          channelDescription: 'Notificações para lembrar de tomar remédios',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  static Future<void> _agendarDiaria({
    required int id,
    required String titulo,
    required String corpo,
    required int hora,
    required int minuto,
    int? horaAjuste,
  }) async {
    final horaFinal = (horaAjuste ?? hora) % 24;
    final minutoFinal = minuto < 0 ? minuto + 60 : minuto % 60;

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

    await _plugin.zonedSchedule(
      id,
      titulo,
      corpo,
      agendado,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'remedios_channel',
          'Lembretes de Remédios',
          channelDescription: 'Notificações para lembrar de tomar remédios',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
