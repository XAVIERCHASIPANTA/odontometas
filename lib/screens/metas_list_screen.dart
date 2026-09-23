import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/meta_goal.dart';
import '../services/storage_service.dart';
import '../services/config_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/estilo_metas.dart';
import '../widgets/fondo_decorativo.dart';
import 'meta_detail_screen.dart';

class MetasListScreen extends StatefulWidget {
  const MetasListScreen({super.key});

  @override
  State<MetasListScreen> createState() => _MetasListScreenState();
}

class _MetasListScreenState extends State<MetasListScreen> {
  List<MetaGoal> _metas = [];
  bool _cargando = true;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final metas = await StorageService.cargarMetas();
    if (!mounted) {
      return;
    }
    setState(() {
      _metas = metas;
      _cargando = false;
    });
  }

  Future<void> _guardar() async {
    await StorageService.guardarMetas(_metas);
  }

  void _editarNombreDoctor() async {
    final actual = await ConfigService.obtenerNombreDoctor() ?? '';
    if (!mounted) {
      return;
    }
    final ctrl = TextEditingController(text: actual);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre que aparecerá en los mensajes de WhatsApp',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nombre = ctrl.text.trim();
              if (nombre.isEmpty) {
                return;
              }
              await ConfigService.guardarNombreDoctor(nombre);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _probarNotificacion() async {
    try {
      await NotificationService.programarNotificacionDePrueba();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Notificación de prueba programada para dentro de 10 segundos. '
            'Cierra la app (o deja el celular en reposo) y espera.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al programar la prueba: $e')),
      );
    }
  }

  void _abrirPermisosAlarmas() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Permisos de alarmas'),
        content: const Text(
          'Esto abrirá la pantalla de Android donde puedes activar el '
          'permiso de "Alarmas y recordatorios" para que los recordatorios '
          'de citas suenen puntuales, incluso si el celular está en reposo.\n\n'
          'Nota: en algunos celulares (especialmente Honor/Huawei) ese '
          'interruptor puede aparecer bloqueado por el propio sistema. Si '
          'pasa eso, no te preocupes: los recordatorios igual funcionan, '
          'solo que podrían llegar con unos minutos de diferencia en vez de '
          'exactos al segundo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await NotificationService.solicitarPermisosManualmente();
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  Future<void> _restaurarDatos() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar desde la nube'),
        content: const Text(
          'Esto va a traer la última copia guardada en la nube para esta '
          'cuenta y reemplazar los datos que ves ahora mismo en este '
          'celular. Úsalo si acabas de instalar la app en un teléfono '
          'nuevo, o si crees que faltan datos que ya se habían guardado.\n\n'
          '¿Deseas continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmar != true) {
      return;
    }
    setState(() => _cargando = true);
    await StorageService.sincronizarAlIniciarSesion();
    await _cargarDatos();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos restaurados desde la nube.')),
    );
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          'Tus datos seguirán respaldados en la nube con esta cuenta. La '
          'próxima vez que alguien abra la app, tendrá que iniciar sesión '
          'de nuevo para verlos.\n\n¿Deseas cerrar sesión ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await AuthService.cerrarSesion();
      // El StreamBuilder en main.dart detecta el cierre de sesión y
      // muestra automáticamente la pantalla de inicio de sesión.
    }
  }

  void _mostrarDialogoNuevaMeta() {
    final tituloCtrl = TextEditingController();
    final metaCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nueva meta'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título (ej. Extracciones)',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: metaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número de meta (ej. 10)',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final titulo = tituloCtrl.text.trim();
                final numero = int.tryParse(metaCtrl.text.trim()) ?? 0;
                if (titulo.isEmpty || numero <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresa un título y un número válido'),
                    ),
                  );
                  return;
                }
                final nuevaMeta = MetaGoal(
                  id: _uuid.v4(),
                  titulo: titulo,
                  metaNumero: numero,
                );
                setState(() {
                  _metas.add(nuevaMeta);
                });
                _guardar();
                Navigator.pop(ctx);
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  void _confirmarEliminar(MetaGoal meta) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar meta'),
        content: Text(
          '¿Seguro que deseas eliminar "${meta.titulo}"? Se perderán todos los datos de pacientes registrados en esta meta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _metas.removeWhere((m) => m.id == meta.id);
              });
              _guardar();
              Navigator.pop(ctx);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirDetalle(MetaGoal meta) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MetaDetailScreen(meta: meta)),
    );
    await _cargarDatos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarConGradiente(
        titulo: '',
        mostrarLogo: false,
        acciones: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Probar notificación',
            onPressed: _probarNotificacion,
          ),
          IconButton(
            icon: const Icon(Icons.alarm_outlined),
            tooltip: 'Permisos de alarmas',
            onPressed: _abrirPermisosAlarmas,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Editar tu nombre',
            onPressed: _editarNombreDoctor,
          ),
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: 'Restaurar desde la nube',
            onPressed: _restaurarDatos,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarDialogoNuevaMeta,
        icon: const Icon(Icons.add),
        label: const Text('Nueva meta'),
      ),
      body: FondoDecorativo(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Image.asset(
                'assets/images/banner_logo.png',
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _metas.isEmpty
                      ? _vacioWidget()
                      : RefreshIndicator(
                          onRefresh: _cargarDatos,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            itemCount: _metas.length,
                            itemBuilder: (ctx, i) {
                              final meta = _metas[i];
                              return _tarjetaMeta(meta);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vacioWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🦷', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes metas creadas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca "Nueva meta" para registrar, por ejemplo, Extracciones, Endodoncias o Calzas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaMeta(MetaGoal meta) {
    final colorPar = colorParaMeta(meta.id);
    final icono = iconoParaProcedimiento(meta.titulo);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: colorPar.fuerte,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => _abrirDetalle(meta),
        onLongPress: () => _confirmarEliminar(meta),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(
                icono,
                size: 90,
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icono, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          meta.titulo,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white),
                        onPressed: () => _confirmarEliminar(meta),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: meta.progreso,
                      minHeight: 10,
                      backgroundColor: Colors.white.withValues(alpha: 0.30),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${meta.completados} / ${meta.metaNumero} pacientes agendados',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
