class Semester {
  const Semester({required this.id, required this.name});

  factory Semester.fromMap(Map<String, dynamic> map) {
    return Semester(id: map['id'] as String, name: map['name'] as String);
  }

  final String id;
  final String name;
}

class Assessment {
  const Assessment({
    required this.id,
    required this.title,
    required this.weightPct,
    required this.maxMarks,
    required this.obtainedMarks,
  });

  factory Assessment.fromMap(Map<String, dynamic> map) {
    return Assessment(
      id: map['id'] as String,
      title: map['title'] as String,
      weightPct: (map['weight_pct'] as num).toDouble(),
      maxMarks: (map['max_marks'] as num).toDouble(),
      obtainedMarks: (map['obtained_marks'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String title;
  final double weightPct;
  final double maxMarks;
  final double? obtainedMarks;
}

class AcademicSubject {
  const AcademicSubject({
    required this.id,
    required this.name,
    required this.code,
    required this.credits,
    required this.assessments,
  });

  factory AcademicSubject.fromMap(
    Map<String, dynamic> map,
    List<Assessment> assessments,
  ) {
    return AcademicSubject(
      id: map['id'] as String,
      name: map['name'] as String,
      code: map['code'] as String?,
      credits: (map['credits'] as num).toDouble(),
      assessments: assessments,
    );
  }

  final String id;
  final String name;
  final String? code;
  final double credits;
  final List<Assessment> assessments;

  double? get percentage {
    final completed = assessments
        .where((assessment) => assessment.obtainedMarks != null)
        .toList();
    final totalWeight = completed.fold<double>(
      0,
      (sum, assessment) => sum + assessment.weightPct,
    );
    if (completed.isEmpty || totalWeight == 0) return null;

    final weighted = completed.fold<double>(
      0,
      (sum, assessment) =>
          sum +
          (assessment.obtainedMarks! / assessment.maxMarks) *
              assessment.weightPct,
    );
    return weighted / totalWeight * 100;
  }
}

class AcademicSnapshot {
  const AcademicSnapshot({required this.semester, required this.subjects});

  final Semester? semester;
  final List<AcademicSubject> subjects;
}

class TimetableSlot {
  const TimetableSlot({
    required this.id,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.subjectName,
    required this.room,
  });

  factory TimetableSlot.fromMap(Map<String, dynamic> map) {
    final subject = map['subject'];
    return TimetableSlot(
      id: map['id'] as String,
      day: map['day_of_week'] as int,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      subjectName: subject is Map
          ? subject['name'] as String? ?? 'Untitled class'
          : 'Untitled class',
      room: map['room'] as String?,
    );
  }

  final String id;
  final int day;
  final String startTime;
  final String endTime;
  final String subjectName;
  final String? room;
}
