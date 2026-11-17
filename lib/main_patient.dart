import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import '/backend/supabase/supabase.dart';
import 'backend/firebase/firebase_config.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'services/i18n_service.dart';
import 'main.dart';
import 'index.dart';

/// Punto de entrada exclusivo para la Plataforma de Pacientes de MediConnect.
/// Compilación y ejecución:
/// flutter run -t lib/main_patient.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoRouter.optionURLReflectsImperativeAPIs = true;
  usePathUrlStrategy();

  await initFirebase();
  await SupaFlow.initialize();
  await FlutterFlowTheme.initialize();
  await I18nService.instance.init();

  runApp(const MyApp(
    appTitle: 'Doctuario - Pacientes',
    initialLoggedInWidget: _buildPatientNavBar,
  ));
}

Widget _buildPatientNavBar(BuildContext context) => const PatientNavBar();

/// Barra de navegación principal enfocada exclusivamente en el paciente.
class PatientNavBar extends StatefulWidget {
  const PatientNavBar({
    super.key,
    this.initialPage,
    this.page,
  });

  final String? initialPage;
  final Widget? page;

  @override
  State<PatientNavBar> createState() => _PatientNavBarState();
}

class _PatientNavBarState extends State<PatientNavBar> {
  String _currentPageName = 'Home';
  Widget? _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPageName = widget.initialPage ?? _currentPageName;
    _currentPage = widget.page;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = SupaFlow.client.auth.currentUser?.id ?? '';

    final tabs = {
      'Home': const HomeWidget(),
      'DoctorsList': const DoctorsListWidget(),
      'MyAppointment': const MyAppointmentWidget(),
      'MyResults': PatientExamsWidget(idPaciente: currentUserId),
      'MyAccount': const MyAccountWidget(),
    };

    final currentIndex = tabs.keys.toList().indexOf(_currentPageName);
    final indexValido = currentIndex >= 0 ? currentIndex : 0;

    return Scaffold(
      body: _currentPage ?? tabs.values.toList()[indexValido],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: indexValido,
        onTap: (i) => safeSetState(() {
          _currentPage = null;
          _currentPageName = tabs.keys.toList()[i];
        }),
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF00796B),
        unselectedItemColor: Colors.grey.shade600,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.person_search),
            label: 'Doctores',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Mis Citas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.picture_as_pdf_outlined),
            activeIcon: Icon(Icons.picture_as_pdf),
            label: 'Exámenes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Mi Cuenta',
          ),
        ],
      ),
    );
  }
}
