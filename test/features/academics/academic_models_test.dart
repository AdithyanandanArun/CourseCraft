import 'package:coursecraft/features/academics/domain/academic_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes entered weighted assessments', () {
    final subject = AcademicSubject(
      id: 'subject',
      name: 'Algorithms',
      code: null,
      credits: 4,
      attendanceTarget: 75,
      assessments: const [
        Assessment(
          id: 'one',
          title: 'Quiz',
          weightPct: 20,
          maxMarks: 20,
          obtainedMarks: 16,
        ),
        Assessment(
          id: 'two',
          title: 'Mid-sem',
          weightPct: 40,
          maxMarks: 100,
          obtainedMarks: 90,
        ),
      ],
    );

    expect(subject.percentage, closeTo(86.67, 0.01));
  });

  test('has no percentage until marks exist', () {
    final subject = AcademicSubject(
      id: 'subject',
      name: 'Algorithms',
      code: null,
      credits: 4,
      attendanceTarget: 75,
      assessments: const [
        Assessment(
          id: 'one',
          title: 'Quiz',
          weightPct: 20,
          maxMarks: 20,
          obtainedMarks: null,
        ),
      ],
    );

    expect(subject.percentage, isNull);
  });
}
