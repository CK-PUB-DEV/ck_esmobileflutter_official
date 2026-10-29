import 'package:flutter/material.dart';
import 'package:pushtrial/widgets/ui/ui.dart';

class TeacherEvaluationScreen extends StatelessWidget {
  const TeacherEvaluationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppPage(
      title: 'Teacher evaluation',
      body: EmptyState(
        icon: LucideIcons.clipboardList,
        title: 'Not available right now',
        message:
            'We are working on making this feature available soon. Please check back later.',
      ),
    );
  }
}
