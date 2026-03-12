import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/storage_service.dart';
import 'services/notification_service.dart';
import 'services/permission_service.dart';
import 'services/update_service.dart';
import 'screens/home_screen.dart';
import 'screens/historico_screen.dart';
import 'screens/remedios_screen.dart';
import 'screens/configuracoes_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  final storage = StorageService();
  await storage.init();
  await NotificationService.init();

  // Agendar notificações para os remédios ativos
  final remedios = storage.carregarRemedios();
  final notifSettings = storage.carregarNotificationSettings();
  await NotificationService.agendarNotificacoesRemedios(remedios,
      settings: notifSettings);

  runApp(AppRemedio(storage: storage));
}

class AppRemedio extends StatelessWidget {
  final StorageService storage;
  const AppRemedio({super.key, required this.storage});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remédios da Nanay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF44B4A6),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFF0EBE3),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF44B4A6).withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF44B4A6),
              );
            }
            return TextStyle(fontSize: 12, color: Colors.grey[500]);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF44B4A6));
            }
            return IconThemeData(color: Colors.grey[400]);
          }),
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
      home: MainNavigation(storage: storage),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final StorageService storage;
  const MainNavigation({super.key, required this.storage});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(storage: widget.storage),
      HistoricoScreen(storage: widget.storage),
      RemediosScreen(storage: widget.storage),
      ConfiguracoesScreen(storage: widget.storage),
    ];
    // Verifica permissões ao abrir o app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PermissionService.verificarEMostrarDialog(context);
      UpdateService.verificarAtualizacao(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Hoje',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Histórico',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Remédios',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}