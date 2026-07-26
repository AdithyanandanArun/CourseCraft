import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/grading/sgpa_engine.dart';

void main() => runApp(const ProviderScope(child: CourseCraftApp()));

class CourseCraftApp extends StatelessWidget {
  const CourseCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CourseCraft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0b6e69)),
        useMaterial3: true,
      ),
      home: const StudentDashboard(),
    );
  }
}

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    const subjects = [
      SubjectGrade(credits: 4, percentage: 86),
      SubjectGrade(credits: 3, percentage: 91),
      SubjectGrade(credits: 3, percentage: 78),
    ];
    final sgpa = SgpaEngine.calculate(subjects);

    return Scaffold(
      appBar: AppBar(title: const Text('CourseCraft')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Student workspace',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your academic plan works before an advisor is connected.',
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Projected SGPA'),
                  const SizedBox(height: 8),
                  Text(
                    sgpa.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  const Text('Target: 9.50'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const ListTile(
            leading: Icon(Icons.menu_book_outlined),
            title: Text('Set up subjects'),
            subtitle: Text('Credits, assessments, and target grades'),
          ),
          const ListTile(
            leading: Icon(Icons.person_add_alt_1_outlined),
            title: Text('Pair an advisor later'),
            subtitle: Text('Optional coaching features unlock after pairing'),
          ),
        ],
      ),
    );
  }
}
