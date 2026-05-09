import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/inventory_provider.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ScanPosApp());
}

class ScanPosApp extends StatelessWidget {
  const ScanPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
      ],
      child: MaterialApp(
        title: 'ScanPos',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Routes users to the correct screen based on their auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    switch (authProvider.state) {
      case AuthState.loading:
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                _SplashLogo(),
                SizedBox(height: 32),
                CircularProgressIndicator(
                  color: AppTheme.black,
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        );

      case AuthState.unauthenticated:
        return const SignInScreen();

      case AuthState.needsRoleSelection:
        return const RoleSelectionScreen();

      case AuthState.pendingApproval:
        return const PendingApprovalScreen();

      case AuthState.authenticated:
        return const AppShell();
    }
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            color: AppTheme.black,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'S',
              style: TextStyle(
                color: AppTheme.white,
                fontSize: 48,
                fontWeight: FontWeight.w700,
                letterSpacing: -2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('ScanPos', style: AppTheme.headlineLg),
      ],
    );
  }
}
