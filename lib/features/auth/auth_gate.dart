import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../home/home_dashboard_page.dart';
import 'sign_in_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({required this.client, super.key});

  final SupabaseClient client;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Session? _session;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _session = widget.client.auth.currentSession;
    _authSubscription = widget.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      if (!mounted) return;
      setState(() => _session = authState.session);
    });
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client) {
      _authSubscription?.cancel();
      _session = widget.client.auth.currentSession;
      _authSubscription = widget.client.auth.onAuthStateChange.listen((
        authState,
      ) {
        if (mounted) setState(() => _session = authState.session);
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) return SignInPage(client: widget.client);
    return HomeDashboardPage(client: widget.client);
  }
}
