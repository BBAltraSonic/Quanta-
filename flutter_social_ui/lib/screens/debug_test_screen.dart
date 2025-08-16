import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class DebugTestScreen extends StatelessWidget {
  const DebugTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Testing'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Test Sentry error reporting
                Sentry.captureMessage('Test message from debug screen');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test message sent to Sentry')),
                );
              },
              child: const Text('Send Test Message to Sentry'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Test exception reporting
                Sentry.captureException(
                  Exception('Test exception from debug screen'),
                  stackTrace: StackTrace.fromString('Test stack trace'),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test exception sent to Sentry')),
                );
              },
              child: const Text('Send Test Exception to Sentry'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Test crash
                throw Exception('Test crash from debug screen');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Trigger Test Crash'),
            ),
          ],
        ),
      ),
    );
  }
}