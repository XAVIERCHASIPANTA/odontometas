import 'package:flutter/material.dart';
import 'metas_list_screen.dart';
import 'calendar_screen.dart';
import 'caja_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La pantalla se recrea al cambiar de pestaña, así la Caja siempre
      // muestra los datos más recientes.
      body: switch (_indice) {
        0 => const MetasListScreen(),
        1 => const CalendarScreen(),
        _ => const CajaScreen(),
      },
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indice,
        onTap: (i) => setState(() => _indice = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.flag_outlined),
            activeIcon: Icon(Icons.flag),
            label: 'Metas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.savings_outlined),
            activeIcon: Icon(Icons.savings),
            label: 'Caja',
          ),
        ],
      ),
    );
  }
}
