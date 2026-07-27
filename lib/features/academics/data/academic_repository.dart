import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/academic_models.dart';

class AcademicRepository {
  AcademicRepository(this._client);

  final SupabaseClient _client;

  Future<AcademicSnapshot> load(String spaceId) async {
    final semesterData = await _client
        .from('semesters')
        .select('id, name')
        .eq('space_id', spaceId)
        .eq('status', 'active')
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (semesterData == null) {
      return const AcademicSnapshot(semester: null, subjects: []);
    }

    final semester = Semester.fromMap(Map<String, dynamic>.from(semesterData));
    final subjectRows = await _client
        .from('subjects')
        .select('id, name, code, credits')
        .eq('semester_id', semester.id)
        .order('created_at');
    final subjects = (subjectRows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    if (subjects.isEmpty) {
      return AcademicSnapshot(semester: semester, subjects: const []);
    }

    final subjectIds = subjects
        .map((subject) => subject['id'] as String)
        .toList();
    final assessmentRows = await _client
        .from('assessments')
        .select('id, subject_id, title, weight_pct, max_marks, obtained_marks')
        .inFilter('subject_id', subjectIds)
        .order('created_at');
    final assessmentsBySubject = <String, List<Assessment>>{};
    for (final row in assessmentRows as List) {
      final data = Map<String, dynamic>.from(row as Map);
      assessmentsBySubject
          .putIfAbsent(data['subject_id'] as String, () => [])
          .add(Assessment.fromMap(data));
    }

    return AcademicSnapshot(
      semester: semester,
      subjects: subjects
          .map(
            (subject) => AcademicSubject.fromMap(
              subject,
              assessmentsBySubject[subject['id'] as String] ?? const [],
            ),
          )
          .toList(),
    );
  }

  Future<void> createSemester({
    required String spaceId,
    required String name,
  }) async {
    await _client.from('semesters').insert({
      'space_id': spaceId,
      'name': name.trim(),
      'status': 'active',
    });
  }

  Future<void> createSubject({
    required String spaceId,
    required String semesterId,
    required String name,
    required String? code,
    required double credits,
  }) async {
    await _client.from('subjects').insert({
      'space_id': spaceId,
      'semester_id': semesterId,
      'name': name.trim(),
      'code': code?.trim().isEmpty ?? true ? null : code!.trim(),
      'credits': credits,
    });
  }

  Future<void> createAssessment({
    required String spaceId,
    required String subjectId,
    required String title,
    required double weightPct,
    required double maxMarks,
    required double? obtainedMarks,
  }) async {
    await _client.from('assessments').insert({
      'space_id': spaceId,
      'subject_id': subjectId,
      'title': title.trim(),
      'weight_pct': weightPct,
      'max_marks': maxMarks,
      'obtained_marks': obtainedMarks,
    });
  }

  Future<Map<String, dynamic>> importTimetable({
    required String spaceId,
    required String semesterId,
    required Map<String, dynamic> timetable,
  }) async {
    final response = await _client.rpc(
      'import_timetable_json',
      params: {
        'p_space_id': spaceId,
        'p_semester_id': semesterId,
        'p_timetable': timetable,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  Future<List<TimetableSlot>> loadTimetable(String spaceId) async {
    final rows = await _client
        .from('timetable_slots')
        .select(
          'id, day_of_week, start_time, end_time, room, subject:subjects(name)',
        )
        .eq('space_id', spaceId)
        .order('day_of_week')
        .order('start_time');
    return (rows as List)
        .map(
          (row) => TimetableSlot.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<void> recordAttendance({
    required String spaceId,
    required String subjectId,
    required String status,
  }) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    await _client.from('attendance').upsert({
      'space_id': spaceId,
      'subject_id': subjectId,
      'date': date,
      'status': status,
    }, onConflict: 'subject_id,date');
  }
}
