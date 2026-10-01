import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ayuda_temas.dart';
import '../models/meta_goal.dart';
import '../services/ayuda_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ayuda_cuerpo.dart';

/// Centro de ayuda: todas las explicaciones agrupadas, y el estado del
/// respaldo en la nube (con botón para sincronizar y las reglas de Firebase).
class CentroAyudaScreen extends StatefulWidget {
  final String? temaInicial;
  const CentroAyudaScreen({super.key, this.temaInicial});

  @override
  State<CentroAyudaScreen> createState() => _CentroAyudaScreenState();
}

class _CentroAyudaScreenState extends State<CentroAyudaScreen> {
  List<MetaGoal> _locales = [];
  ResumenNube? _nube;
  bool _consultando = true;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  int _contarPacientes(List<MetaGoal> metas) =>
      metas.fold(0, (s, m) => s + m.pacientes.where((p) => p != null).length);

  Future<void> _cargar() async {
    setState(() => _consultando = true);
    final locales = await StorageService.cargarMetas();
    final nube = await SyncService.contarNube();
    if (!mounted) {
      return;
    }
    setState(() {
      _locales = locales;
      _nube = nube;
      _consultando = false;
    });
  }

  Future<void> _sincronizar() async {
    setState(() => _sincronizando = true);
    try {
      final locales = await StorageService.cargarMetas();
      await SyncService.sincronizarAhora(locales);
    } finally {
      if (mounted) {
        setState(() => _sincronizando = false);
      }
    }
    await _cargar();
  }

  String _hace(DateTime? d) {
    if (d == null) {
      return 'todavía no en esta sesión';
    }
    final seg = DateTime.now().difference(d).inSeconds;
    if (seg < 60) {
      return 'hace un momento';
    }
    if (seg < 3600) {
      return 'hace ${seg ~/ 60} min';
    }
    if (seg < 86400) {
      return 'hace ${seg ~/ 3600} h';
    }
    return 'hace ${seg ~/ 86400} días';
  }

  @override
  Widget build(BuildContext context) {
    final inicial =
        widget.temaInicial == null ? null : temasAyuda[widget.temaInicial];
    return Scaffold(
      backgroundColor: AppTheme.fondo,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('Centro de ayuda'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.rosaOscuro, AppTheme.lavanda],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          _tarjetaNube(),
          if (inicial != null) ...[
            const SizedBox(height: 16),
            _encabezadoGrupo('Tema que estabas viendo'),
            _tarjetaTema(inicial, expandido: true),
          ],
          for (final grupo in ordenGruposAyuda) ...[
            const SizedBox(height: 16),
            _encabezadoGrupo(grupo),
            for (final t in temasAyuda.values.where((t) => t.grupo == grupo))
              _tarjetaTema(t),
          ],
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: () async {
                await AyudaService.reiniciar();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Las guías de primera vez volverán a aparecer al entrar a cada pantalla.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.replay),
              label: const Text('Volver a mostrar las guías de primera vez'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _encabezadoGrupo(String texto) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _tarjetaTema(AyudaTema t, {bool expandido = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: t.color.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('ayuda_${t.clave}_$expandido'),
          initiallyExpanded: expandido,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [t.color, t.colorOscuro]),
              shape: BoxShape.circle,
            ),
            child: Icon(t.icono, color: Colors.white, size: 20),
          ),
          title: Text(
            t.titulo,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          children: [CuerpoAyuda(tema: t)],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Estado de la nube
  // ------------------------------------------------------------------

  Widget _tarjetaNube() {
    const color = Color(0xFF5C6BC0);
    const oscuro = Color(0xFF283593);
    return ValueListenableBuilder<EstadoNube>(
      valueListenable: SyncService.estado,
      builder: (context, estado, _) {
        final (icono, colorEstado, titulo) = switch (estado.fase) {
          FaseNube.ok => (Icons.cloud_done, Colors.green.shade700, 'Respaldo al día'),
          FaseNube.sincronizando => (Icons.cloud_sync, color, 'Sincronizando…'),
          FaseNube.error => (Icons.cloud_off, Colors.red.shade700, 'Hay un problema con la nube'),
          FaseNube.sinSesion => (Icons.person_off_outlined, Colors.orange.shade800, 'Sin sesión iniciada'),
          FaseNube.inactiva => (Icons.cloud_queue, color, 'Respaldo en la nube'),
        };
        final pacientesLocales = _contarPacientes(_locales);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorEstado.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: colorEstado.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: colorEstado, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: colorEstado,
                          ),
                        ),
                        Text(
                          'Última subida: ${_hace(estado.ultima)}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (estado.mensaje.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(estado.mensaje),
              ],
              for (final a in estado.advertencias)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: Colors.orange.shade800),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          a,
                          style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 22),
              _linea(
                Icons.phone_android,
                'En este teléfono',
                _consultando
                    ? 'consultando…'
                    : '$pacientesLocales paciente(s) en ${_locales.length} meta(s)',
              ),
              const SizedBox(height: 4),
              _linea(
                Icons.cloud_outlined,
                'En la nube',
                _consultando
                    ? 'consultando…'
                    : _nube == null
                        ? 'no se pudo consultar'
                        : '${_nube!.pacientes} paciente(s) en ${_nube!.metas} meta(s)'
                            '${_nube!.formatoNuevo ? '  ·  formato nuevo ✓' : '  ·  formato anterior'}',
              ),
              if (!_consultando &&
                  _nube != null &&
                  _nube!.formatoNuevo &&
                  pacientesLocales > _nube!.pacientes)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Hay más pacientes en el teléfono que en la nube: toca «Sincronizar ahora».',
                    style: TextStyle(fontSize: 12.5, color: Colors.orange.shade900),
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _sincronizando ? null : _sincronizar,
                    style: FilledButton.styleFrom(backgroundColor: oscuro),
                    icon: _sincronizando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: const Text('Sincronizar ahora'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _consultando ? null : _cargar,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 4),
                  title: const Text(
                    'Reglas de Firestore (si sale error de permisos)',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'En la consola de Firebase → Firestore Database → Reglas, AGREGA este '
                      'bloque dentro de «match /databases/{database}/documents { … }» '
                      '(sin borrar tus reglas actuales):',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF263238),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const SelectableText(
                        reglasFirestoreSugeridas,
                        style: TextStyle(
                          color: Color(0xFFB2FF59),
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            const ClipboardData(text: reglasFirestoreSugeridas),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Reglas copiadas.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copiar'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _linea(IconData icono, String etiqueta, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(etiqueta, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
