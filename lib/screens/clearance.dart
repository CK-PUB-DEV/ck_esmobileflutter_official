import 'package:flutter/material.dart';
import 'package:pushtrial/widgets/ui/ui.dart';

class ClearanceScreen extends StatelessWidget {
  const ClearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Clearance',
      body: EmptyState(
        icon: LucideIcons.fileCheck,
        title: 'Not available right now',
        message:
            'We are working on making this feature available soon. Please check back later.',
      ),
    );
  }
}
