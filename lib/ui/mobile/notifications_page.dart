import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import 'notifications_body.dart';

/// Impostazioni > **Notifiche**.
///
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifiche')),
        body: ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.l),
          itemCount: 1,
          itemBuilder: (_, index) => const NotificationsBody(),
        ),
      );
}
