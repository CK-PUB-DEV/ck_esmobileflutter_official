import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('Shad input validates inside a Material form', (tester) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ShadApp.custom(
        theme: ShadThemeData(colorScheme: const ShadRedColorScheme.light()),
        appBuilder: (context) => MaterialApp(
          theme: Theme.of(context),
          localizationsDelegates: const [
            GlobalShadLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) => ShadAppBuilder(child: child!),
          home: Scaffold(
            body: Form(
              key: formKey,
              child: ShadInputFormField(
                controller: controller,
                placeholder: const Text('Username'),
                validator: (value) => value.isEmpty ? 'Required' : null,
              ),
            ),
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.enterText(find.byType(EditableText), 'student');
    await tester.pump();
    expect(formKey.currentState!.validate(), isTrue);
    expect(controller.text, 'student');
  });
}
