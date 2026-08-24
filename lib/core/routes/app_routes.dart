import 'package:flutter/material.dart';
import '../../screens/app_shell.dart';
import '../../screens/auth/auth_screens.dart';
import '../../screens/component_showcase/component_showcase_screen.dart';
import '../../screens/component_showcase/prototype_demo_screen.dart';
import '../../screens/incidents/incident_details_screen.dart';
import '../../screens/incidents/incident_list_screen.dart';
import '../../models/models.dart';

abstract final class AppRoutes {
  static const login = '/';
  static const home = '/home';
  static const forgotPassword = '/forgot-password';
  static const otp = '/otp';
  static const newPassword = '/new-password';
  static const passwordChanged = '/password-changed';
  static const showcase = '/showcase';
  static const prototypeDemo = '/prototype-demo';
  static const incidentList = '/incidents';
  static const incidentDetails = '/incident-details';
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    final page = switch (settings.name) {
      home => const AppShell(),
      forgotPassword => const ForgotPasswordScreen(),
      otp => const OtpVerificationScreen(),
      newPassword => const CreateNewPasswordScreen(),
      passwordChanged => const PasswordChangedScreen(),
      showcase => const ComponentShowcaseScreen(),
      prototypeDemo => const PrototypeDemoScreen(),
      incidentList => IncidentListScreen(
        initialFilter: settings.arguments as IncidentListFilter?,
      ),
      incidentDetails => IncidentDetailsScreen(
        incident: settings.arguments! as CapIncident,
      ),
      _ => const LoginScreen(),
    };
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) => SlideTransition(
        position: Tween(
          begin: const Offset(.04, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
        child: FadeTransition(opacity: animation, child: page),
      ),
    );
  }
}
