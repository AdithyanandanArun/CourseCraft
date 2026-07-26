class SubjectGrade {
  const SubjectGrade({required this.credits, required this.percentage});

  final int credits;
  final double percentage;
}

class SgpaEngine {
  static double calculate(Iterable<SubjectGrade> subjects) {
    final valid = subjects.where((subject) => subject.credits > 0).toList();
    final credits = valid.fold<int>(0, (sum, subject) => sum + subject.credits);
    if (credits == 0) return 0;

    final weightedPoints = valid.fold<double>(
      0,
      (sum, subject) => sum + subject.credits * gradePoint(subject.percentage),
    );
    return weightedPoints / credits;
  }

  static double gradePoint(double percentage) {
    if (percentage >= 90) return 10;
    if (percentage >= 80) return 9;
    if (percentage >= 70) return 8;
    if (percentage >= 60) return 7;
    if (percentage >= 50) return 6;
    if (percentage >= 40) return 5;
    return 0;
  }
}
