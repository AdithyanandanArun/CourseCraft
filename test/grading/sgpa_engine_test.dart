import 'package:coursecraft/core/grading/sgpa_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates credit-weighted SGPA', () {
    final result = SgpaEngine.calculate(const [
      SubjectGrade(credits: 4, percentage: 86),
      SubjectGrade(credits: 3, percentage: 91),
      SubjectGrade(credits: 3, percentage: 78),
    ]);

    expect(result, 9.0);
  });

  test('returns zero without valid credits', () {
    expect(
      SgpaEngine.calculate(const [SubjectGrade(credits: 0, percentage: 95)]),
      0,
    );
  });
}
