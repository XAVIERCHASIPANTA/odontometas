import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'config_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  static Future<void> inicializar() async {
    if (_inicializado) {
      return;
    }
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/Guayaquil'));
    } catch (_) {
      // Si no se encuentra la zona horaria, se continúa con la zona por defecto.
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    // Solo se piden los permisos la primera vez que se abre la app, para no
    // interrumpir cada apertura con la pantalla de configuración de Android.
    final yaSolicitados = await ConfigService.yaSolicitoPermisos();
    if (!yaSolicitados) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      await ConfigService.marcarPermisosSolicitados();
    }

    _inicializado = true;
  }

  /// Permite volver a abrir la pantalla de permisos manualmente desde un
  /// botón en Ajustes, por si el usuario los rechazó por error la primera vez.
  static Future<void> solicitarPermisosManualmente() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await ConfigService.marcarPermisosSolicitados();
  }

  static int _idPara(String metaId, int indice, int variante) {
    return (metaId.hashCode ^ (indice * 7919) ^ (variante * 104729)) &
        0x7fffffff;
  }

  static NotificationDetails _detalles() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'odontometas_citas',
        'Recordatorio de citas',
        channelDescription: 'Avisos de citas odontológicas agendadas',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  /// Detecta si el permiso de alarmas exactas está disponible. Si el celular
  /// no lo permite (como en tu caso, donde el switch aparece bloqueado), la
  /// app usa un modo "aproximado" que no necesita ese permiso especial: el
  /// recordatorio igual llega, con una pequeña posibilidad de retraso de
  /// unos minutos si el celular está en reposo profundo.
  static Future<AndroidScheduleMode> _modoDeProgramacion() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      final puedeExacto = await androidPlugin?.canScheduleExactNotifications();
      if (puedeExacto == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      // Si el dispositivo no soporta esta consulta, se usa el modo seguro.
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Programa dos recordatorios: uno el mismo día/hora de la cita y otro
  /// 24 horas antes.
  static Future<void> programarRecordatorios({
    required String metaId,
    required int indice,
    required String tituloProcedimiento,
    required String nombrePaciente,
    required DateTime fechaHora,
  }) async {
    final ahora = tz.TZDateTime.now(tz.local);
    final modo = await _modoDeProgramacion();

    final idExacto = _idPara(metaId, indice, 0);
    final programadaExacta = tz.TZDateTime.from(fechaHora, tz.local);
    if (programadaExacta.isAfter(ahora)) {
      try {
        await _plugin.zonedSchedule(
          idExacto,
          'Cita hoy: $tituloProcedimiento',
          'Paciente: $nombrePaciente',
          programadaExacta,
          _detalles(),
          androidScheduleMode: modo,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // Si aun así falla, se evita que se caiga toda la app por esto.
      }
    } else {
      await _plugin.cancel(idExacto);
    }

    final idDiaAntes = _idPara(metaId, indice, 1);
    final unDiaAntes = fechaHora.subtract(const Duration(days: 1));
    final programadaAntes = tz.TZDateTime.from(unDiaAntes, tz.local);
    if (programadaAntes.isAfter(ahora)) {
      try {
        await _plugin.zonedSchedule(
          idDiaAntes,
          'Mañana tiene cita: $tituloProcedimiento',
          'Paciente: $nombrePaciente — recuerda enviarle el recordatorio',
          programadaAntes,
          _detalles(),
          androidScheduleMode: modo,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        // Igual aquí: no se interrumpe el guardado del paciente por esto.
      }
    } else {
      await _plugin.cancel(idDiaAntes);
    }
  }

  static Future<void> cancelarRecordatorios(String metaId, int indice) async {
    await _plugin.cancel(_idPara(metaId, indice, 0));
    await _plugin.cancel(_idPara(metaId, indice, 1));
  }
}
