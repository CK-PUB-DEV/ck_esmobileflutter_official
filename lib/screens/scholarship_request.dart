import 'package:flutter/material.dart';
import 'package:pushtrial/widgets/ui/ui.dart';

class ScholarshipRequestScreen extends StatelessWidget {
  const ScholarshipRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Scholarship request',
      body: EmptyState(
        icon: LucideIcons.graduationCap,
        title: 'Not available for your school',
        message: 'Scholarship requests are not offered through the app yet.',
      ),
    );
  }
}
