import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/grading/sgpa_engine.dart';
import 'core/services/supabase_service.dart';
import 'features/academics/data/academic_repository.dart';
import 'features/academics/domain/academic_models.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/app_profile.dart';

const _surface = Color(0xffe0e5ec);
const _ink = Color(0xff3d4852);
const _muted = Color(0xff6b7280);
const _accent = Color(0xff6c63ff);
const _shadowDark = Color(0xffa3b1c6);
const _darkSurface = Color(0xff202833);
const _darkInk = Color(0xffedf1f5);
const _darkMuted = Color(0xffb8c1cb);
const _darkShadow = Color(0xff070a10);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.fromEnvironment();
  if (config.isSupabaseConfigured) {
    await SupabaseService.initialize(config);
  }
  runApp(CourseCraftApp(config: config));
}

class CourseCraftApp extends StatefulWidget {
  const CourseCraftApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<CourseCraftApp> createState() => _CourseCraftAppState();
}

class _CourseCraftAppState extends State<CourseCraftApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'CourseCraft',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: _themeMode,
        builder: (context, child) => ThemeScope(
          isDark: _themeMode == ThemeMode.dark,
          onToggle: () => setState(
            () => _themeMode = _themeMode == ThemeMode.dark
                ? ThemeMode.light
                : ThemeMode.dark,
          ),
          child: child ?? const SizedBox.shrink(),
        ),
        home: widget.config.isSupabaseConfigured
            ? AuthGate(repository: AuthRepository(Supabase.instance.client))
            : const ConfigurationScreen(),
      ),
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? _darkSurface : _surface;
  final ink = dark ? _darkInk : _ink;
  final muted = dark ? _darkMuted : _muted;
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: dark ? const Color(0xffa9a4ff) : _accent,
      brightness: brightness,
      surface: surface,
    ),
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: ink,
      displayColor: ink,
      fontFamily: 'sans-serif',
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      labelStyle: TextStyle(color: muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _accent, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      elevation: 0,
    ),
  );
}

class ThemeScope extends InheritedWidget {
  const ThemeScope({
    super.key,
    required this.isDark,
    required this.onToggle,
    required super.child,
  });

  final bool isDark;
  final VoidCallback onToggle;

  static ThemeScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeScope>()!;

  @override
  bool updateShouldNotify(ThemeScope oldWidget) => isDark != oldWidget.isDark;
}

class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _SoftPanel(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _IconWell(icon: Icons.cloud_off_outlined, size: 26),
                      const SizedBox(height: 20),
                      Text(
                        'Connect CourseCraft',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Launch with SUPABASE_URL and SUPABASE_ANON_KEY Dart defines after applying the Supabase migrations.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(top: 16, right: 16, child: _ThemeToggle()),
        ],
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Session? _session;
  late StreamSubscription<AuthState> _subscription;

  @override
  void initState() {
    super.initState();
    _session = widget.repository.currentSession;
    _subscription = widget.repository.authStateChanges.listen((state) {
      if (mounted) setState(() => _session = state.session);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return AuthScreen(repository: widget.repository);
    return ProfileGate(repository: widget.repository, user: session.user);
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String _role = 'student';
  String? _message;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      if (_isSignUp) {
        final response = await widget.repository.signUp(
          displayName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          role: _role,
        );
        if (response.session == null && mounted) {
          setState(
            () => _message =
                'Check your email to confirm this account, then sign in.',
          );
        }
      } else {
        await widget.repository.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Unable to reach CourseCraft. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    final email = await _textPrompt(
      context: context,
      title: 'Reset password',
      label: 'Email address',
      initialValue: _emailController.text,
    );
    if (email == null || !mounted) return;
    setState(() {
      _isLoading = true;
      _message = null;
    });
    try {
      await widget.repository.requestPasswordReset(email);
      if (mounted) {
        setState(
          () => _message =
              'If an account exists for this email, a reset link is on its way.',
        );
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Unable to send a reset email. Try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: _SoftPanel(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _BrandTitle(),
                          const SizedBox(height: 8),
                          Text(
                            _isSignUp
                                ? 'Build your own academic system.'
                                : 'Welcome back.',
                          ),
                          const SizedBox(height: 32),
                          if (_isSignUp) ...[
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Name',
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter your name.'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'student',
                                  label: Text('Student'),
                                  icon: Icon(Icons.school_outlined),
                                ),
                                ButtonSegment(
                                  value: 'advisor',
                                  label: Text('Advisor'),
                                  icon: Icon(Icons.support_agent_outlined),
                                ),
                              ],
                              selected: {_role},
                              onSelectionChanged: (value) =>
                                  setState(() => _role = value.first),
                            ),
                            const SizedBox(height: 16),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
                            validator: (value) =>
                                value == null || !value.contains('@')
                                ? 'Enter a valid email.'
                                : null,
                          ),
                          if (!_isSignUp)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : _requestPasswordReset,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            decoration: const InputDecoration(
                              labelText: 'Password',
                            ),
                            validator: (value) =>
                                value == null || value.length < 8
                                ? 'Use at least 8 characters.'
                                : null,
                          ),
                          if (_message != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _message!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _PrimaryButton(
                            onPressed: _isLoading ? null : _submit,
                            child: Text(
                              _isLoading
                                  ? 'Please wait...'
                                  : _isSignUp
                                  ? 'Create account'
                                  : 'Sign in',
                            ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() {
                                    _isSignUp = !_isSignUp;
                                    _message = null;
                                  }),
                            child: Text(
                              _isSignUp
                                  ? 'Already have an account? Sign in'
                                  : 'Create a new account',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(top: 8, right: 16, child: _ThemeToggle()),
          ],
        ),
      ),
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key, required this.repository, required this.user});

  final AuthRepository repository;
  final User user;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<AppProfile> _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.repository.ensureProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppProfile>(
      future: _profile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: _SoftLoadingIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _SoftPanel(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('We could not prepare your workspace.'),
                      const SizedBox(height: 12),
                      _PrimaryButton(
                        onPressed: () => setState(
                          () => _profile = widget.repository.ensureProfile(),
                        ),
                        child: const Text('Try again'),
                      ),
                      TextButton(
                        onPressed: widget.repository.signOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return HomeScreen(
          repository: widget.repository,
          profile: snapshot.requireData,
        );
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.profile,
  });

  final AuthRepository repository;
  final AppProfile profile;

  @override
  Widget build(BuildContext context) {
    if (!profile.isStudent || profile.spaceId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const _CompactBrand(),
          actions: [
            const _ThemeToggle(),
            IconButton(
              onPressed: repository.signOut,
              icon: const Icon(Icons.logout),
              tooltip: 'Sign out',
            ),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: _SoftPanel(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                  'Your advisor profile is ready. Pairing and coaching tools arrive in Phase 3.',
                ),
              ),
            ),
          ),
        ),
      );
    }
    return StudentHome(repository: repository, profile: profile);
  }
}

class StudentHome extends StatefulWidget {
  const StudentHome({
    super.key,
    required this.repository,
    required this.profile,
  });

  final AuthRepository repository;
  final AppProfile profile;

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  late final AcademicRepository _academics;
  late Future<AcademicSnapshot> _snapshot;
  bool _showPlanning = false;

  @override
  void initState() {
    super.initState();
    _academics = AcademicRepository(Supabase.instance.client);
    _snapshot = _academics.load(widget.profile.spaceId!);
  }

  void _refresh() =>
      setState(() => _snapshot = _academics.load(widget.profile.spaceId!));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const _CompactBrand(),
        actions: [
          const _ThemeToggle(),
          IconButton(
            onPressed: widget.repository.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: FutureBuilder<AcademicSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: _SoftLoadingIndicator());
          }
          if (snapshot.hasError) return _RetryState(onRetry: _refresh);
          final data = snapshot.requireData;
          if (data.semester == null) {
            return _SemesterSetup(onCreate: _createSemester);
          }
          if (_showPlanning) {
            return _PlanningScreen(
              academics: _academics,
              spaceId: widget.profile.spaceId!,
              semester: data.semester!,
              subjects: data.subjects,
              attendanceBySubject: data.attendanceBySubject,
              onBack: () => setState(() => _showPlanning = false),
              onImported: _refresh,
            );
          }
          return _AcademicDashboard(
            profile: widget.profile,
            snapshot: data,
            onAddSubject: () => _addSubject(data.semester!),
            onAddAssessment: (subject) => _addAssessment(subject),
            onOpenPlanning: () => setState(() => _showPlanning = true),
          );
        },
      ),
    );
  }

  Future<void> _createSemester() async {
    final name = await _textPrompt(
      context: context,
      title: 'Create semester',
      label: 'Semester name',
      initialValue: 'Current semester',
    );
    if (name == null) return;
    await _academics.createSemester(
      spaceId: widget.profile.spaceId!,
      name: name,
    );
    _refresh();
  }

  Future<void> _addSubject(Semester semester) async {
    final values = await _subjectPrompt(context);
    if (values == null) return;
    await _academics.createSubject(
      spaceId: widget.profile.spaceId!,
      semesterId: semester.id,
      name: values.name,
      code: values.code,
      credits: values.credits,
    );
    _refresh();
  }

  Future<void> _addAssessment(AcademicSubject subject) async {
    final values = await _assessmentPrompt(context, subject.name);
    if (values == null) return;
    await _academics.createAssessment(
      spaceId: widget.profile.spaceId!,
      subjectId: subject.id,
      title: values.title,
      weightPct: values.weightPct,
      maxMarks: values.maxMarks,
      obtainedMarks: values.obtainedMarks,
    );
    _refresh();
  }
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _PrimaryButton(
        onPressed: onRetry,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh),
            SizedBox(width: 8),
            Text('Retry loading workspace'),
          ],
        ),
      ),
    );
  }
}

const _timetablePrompt =
    '''Analyze the attached timetable image and convert it into JSON format.
1. Group the data hierarchically by Subject.
2. Ignore all teacher or professor names.
3. Clean up subject names by removing group, section, or batch designations. Combine schedules for the same base subject.
4. Use standard straight double quotes, not smart quotes.
5. Return ONLY valid JSON matching this structure:
{"subjects":[{"name":"Subject Name","schedules":[{"day":"Monday","classTimes":[{"startTime":"09:00 AM","endTime":"10:30 AM","roomNumber":"Room 101"}]}]}]}''';

class _PlanningScreen extends StatefulWidget {
  const _PlanningScreen({
    required this.academics,
    required this.spaceId,
    required this.semester,
    required this.subjects,
    required this.attendanceBySubject,
    required this.onBack,
    required this.onImported,
  });
  final AcademicRepository academics;
  final String spaceId;
  final Semester semester;
  final List<AcademicSubject> subjects;
  final Map<String, AttendanceSummary> attendanceBySubject;
  final VoidCallback onBack;
  final VoidCallback onImported;

  @override
  State<_PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<_PlanningScreen> {
  late Future<List<TimetableSlot>> _slots;
  final Set<String> _pendingAttendanceSubjects = {};
  @override
  void initState() {
    super.initState();
    _slots = widget.academics.loadTimetable(widget.spaceId);
  }

  void _reload() =>
      setState(() => _slots = widget.academics.loadTimetable(widget.spaceId));

  Future<void> _adjustAttendance(
    AcademicSubject subject,
    String status,
    int delta,
  ) async {
    setState(() => _pendingAttendanceSubjects.add(subject.id));
    try {
      await widget.academics.adjustAttendance(
        spaceId: widget.spaceId,
        subjectId: subject.id,
        status: status,
        delta: delta,
      );
      widget.onImported();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update attendance: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingAttendanceSubjects.remove(subject.id));
      }
    }
  }

  Future<void> _addPlanningItem(
    String table,
    String title,
    String label,
  ) async {
    final value = await _textPrompt(
      context: context,
      title: title,
      label: label,
    );
    if (value == null || !mounted) return;
    try {
      await widget.academics.addPlanningItem(
        table: table,
        spaceId: widget.spaceId,
        value: value,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $error')));
      }
    }
  }

  Future<void> _import() async {
    final controller = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import timetable'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload your timetable image to an AI model, give it this prompt, then paste only its JSON response.',
                ),
                const SizedBox(height: 12),
                SelectableText(
                  _timetablePrompt,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Timetable JSON',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              try {
                Navigator.pop(
                  context,
                  Map<String, dynamic>.from(jsonDecode(controller.text) as Map),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paste valid JSON without markdown fences.'),
                  ),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || !mounted) return;
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace current timetable?'),
        content: const Text(
          'This replaces all current subjects for this semester. Linked assessments and attendance records will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (replace != true || !mounted) return;
    try {
      final summary = await widget.academics.importTimetable(
        spaceId: widget.spaceId,
        semesterId: widget.semester.id,
        timetable: result,
      );
      _reload();
      widget.onImported();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${summary['slotsCreated']} classes imported.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
      }
    }
  }

  Future<void> _deleteTimetable() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear timetable?'),
        content: const Text(
          'This removes every class and subject in this semester. Linked assessments and attendance records will also be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear timetable'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.academics.deleteTimetable(
        spaceId: widget.spaceId,
        semesterId: widget.semester.id,
      );
      _reload();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Timetable cleared.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not clear timetable: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday;
    return FutureBuilder<List<TimetableSlot>>(
      future: _slots,
      builder: (context, snapshot) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to academics',
              ),
              Expanded(
                child: Text(
                  'Academic planning',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _IconWellButton(
                onPressed: _import,
                icon: Icons.upload_file_outlined,
                tooltip: 'Import timetable',
              ),
              const SizedBox(width: 8),
              _IconWellButton(
                onPressed: _deleteTimetable,
                icon: Icons.delete_outline,
                tooltip: 'Clear timetable',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Import a timetable from AI-generated JSON. Mark attendance manually after each class.',
          ),
          const SizedBox(height: 22),
          _SoftPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today’s timetable',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState != ConnectionState.done)
                  const _SoftLoadingIndicator()
                else
                  ...((snapshot.data ?? [])
                      .where((slot) => slot.day == today)
                      .map(
                        (slot) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(slot.subjectName),
                          subtitle: Text(
                            '${slot.startTime.substring(0, 5)} - ${slot.endTime.substring(0, 5)}${slot.room == null ? '' : ' · ${slot.room}'}',
                          ),
                        ),
                      )),
                if (snapshot.connectionState == ConnectionState.done &&
                    (snapshot.data ?? [])
                        .where((slot) => slot.day == today)
                        .isEmpty)
                  const Text('No classes scheduled today.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SoftPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                for (final subject in widget.subjects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _AttendanceSubjectCard(
                      subject: subject,
                      summary: widget.attendanceBySubject[subject.id] ??
                          const AttendanceSummary(attended: 0, missed: 0),
                      pending: _pendingAttendanceSubjects.contains(subject.id),
                      onAdjust: (status, delta) =>
                          _adjustAttendance(subject, status, delta),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SoftPanel(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan your week',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Keep these personal planning tools in sync with your web workspace.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          _addPlanningItem('tasks', 'Add task', 'Task'),
                      icon: const Icon(Icons.checklist_outlined),
                      label: const Text('Task'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addPlanningItem(
                        'habits',
                        'Add habit',
                        'Daily habit',
                      ),
                      icon: const Icon(Icons.repeat),
                      label: const Text('Habit'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _addPlanningItem('notes', 'Add note', 'Note'),
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Note'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _addPlanningItem(
                        'events',
                        'Add calendar event',
                        'Event title',
                      ),
                      icon: const Icon(Icons.event_outlined),
                      label: const Text('Event'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SemesterSetup extends StatelessWidget {
  const _SemesterSetup({required this.onCreate});

  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _SoftPanel(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _IconWell(icon: Icons.auto_stories_outlined, size: 28),
              const SizedBox(height: 16),
              Text(
                'Start your first semester',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a semester, then add subjects, assessment weights, and marks.',
              ),
              const SizedBox(height: 20),
              _PrimaryButton(
                onPressed: onCreate,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('Create semester'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceSubjectCard extends StatelessWidget {
  const _AttendanceSubjectCard({
    required this.subject,
    required this.summary,
    required this.pending,
    required this.onAdjust,
  });

  final AcademicSubject subject;
  final AttendanceSummary summary;
  final bool pending;
  final Future<void> Function(String status, int delta) onAdjust;

  @override
  Widget build(BuildContext context) {
    final target = subject.attendanceTarget;
    final percentage = summary.percentage;
    final tone = summary.total == 0
        ? _muted
        : percentage >= target
        ? const Color(0xff238b85)
        : percentage >= target - 10
        ? const Color(0xffb88700)
        : const Color(0xffb23b4b);
    final status = summary.total == 0
        ? 'No classes logged'
        : percentage >= target
        ? 'On track'
        : percentage >= target - 10
        ? 'Near target'
        : 'Below target';
    final background = Theme.of(context).colorScheme.surface;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shadow = (dark ? _darkShadow : _shadowDark).withValues(alpha: .62);
    final highlight = (dark ? const Color(0xff4b5b6c) : Colors.white)
        .withValues(alpha: dark ? .3 : .5);

    return Semantics(
      label:
          '${subject.name}: ${summary.attended} attended, ${summary.missed} missed, ${summary.total} total, ${summary.total == 0 ? 'no attendance recorded' : '${percentage.round()} percent'}',
      child: _SoftPanel(
        inset: true,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('$status · target ${target.toStringAsFixed(0)}%'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: shadow,
                        offset: const Offset(5, 5),
                        blurRadius: 10,
                      ),
                      BoxShadow(
                        color: highlight,
                        offset: const Offset(-5, -5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: tone, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _AttendanceCount(label: 'Attended', value: summary.attended),
                      _AttendanceCount(label: 'Missed', value: summary.missed),
                      _AttendanceCount(label: 'Total', value: summary.total),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 106,
                  height: 106,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 106,
                        height: 106,
                        child: CircularProgressIndicator(
                          value: summary.total == 0 ? 0 : percentage / 100,
                          strokeWidth: 11,
                          color: tone,
                          backgroundColor: _muted.withValues(alpha: 0.22),
                        ),
                      ),
                      Container(
                        width: 76,
                        height: 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: background,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: shadow,
                              offset: const Offset(5, 5),
                              blurRadius: 10,
                              spreadRadius: -3,
                            ),
                            BoxShadow(
                              color: highlight,
                              offset: const Offset(-5, -5),
                              blurRadius: 10,
                              spreadRadius: -3,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              summary.total == 0 ? '---' : '${percentage.round()}%',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'attendance',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final attended = _AttendanceAdjuster(
                  label: 'Attended',
                  count: summary.attended,
                  color: const Color(0xff238b85),
                  onDecrease: summary.attended == 0
                      ? null
                      : pending ? null : () => onAdjust('present', -1),
                  onIncrease: pending ? null : () => onAdjust('present', 1),
                );
                final missed = _AttendanceAdjuster(
                  label: 'Missed',
                  count: summary.missed,
                  color: const Color(0xffb23b4b),
                  onDecrease: summary.missed == 0
                      ? null
                      : pending ? null : () => onAdjust('absent', -1),
                  onIncrease: pending ? null : () => onAdjust('absent', 1),
                );
                if (constraints.maxWidth < 340) {
                  return Column(
                    children: [
                      attended,
                      const SizedBox(height: 12),
                      missed,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: attended),
                    const SizedBox(width: 12),
                    Expanded(child: missed),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCount extends StatelessWidget {
  const _AttendanceCount({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

class _AttendanceAdjuster extends StatelessWidget {
  const _AttendanceAdjuster({
    required this.label,
    required this.count,
    required this.color,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String label;
  final int count;
  final Color color;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final shadow = (dark ? _darkShadow : _shadowDark).withValues(alpha: .62);
    final highlight = (dark ? const Color(0xff4b5b6c) : Colors.white)
        .withValues(alpha: dark ? .3 : .5);
    return Container(
    constraints: const BoxConstraints(minHeight: 54),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: shadow,
          offset: const Offset(5, 5),
          blurRadius: 10,
        ),
        BoxShadow(
          color: highlight,
          offset: const Offset(-5, -5),
          blurRadius: 10,
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '$label\n$count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Reduce ${label.toLowerCase()} classes',
          child: IconButton(
            onPressed: onDecrease,
            icon: const Icon(Icons.remove),
            color: color,
            tooltip: 'Reduce ${label.toLowerCase()}',
          ),
        ),
        Semantics(
          button: true,
          label: 'Add ${label.toLowerCase()} class',
          child: IconButton(
            onPressed: onIncrease,
            icon: const Icon(Icons.add),
            color: color,
            tooltip: 'Add ${label.toLowerCase()}',
          ),
        ),
      ],
    ),
    );
  }
}

class _AcademicDashboard extends StatelessWidget {
  const _AcademicDashboard({
    required this.profile,
    required this.snapshot,
    required this.onAddSubject,
    required this.onAddAssessment,
    required this.onOpenPlanning,
  });

  final AppProfile profile;
  final AcademicSnapshot snapshot;
  final VoidCallback onAddSubject;
  final Future<void> Function(AcademicSubject) onAddAssessment;
  final VoidCallback onOpenPlanning;

  @override
  Widget build(BuildContext context) {
    final graded = snapshot.subjects
        .where((subject) => subject.percentage != null)
        .map(
          (subject) => SubjectGrade(
            credits: subject.credits.round(),
            percentage: subject.percentage!,
          ),
        )
        .toList();
    final sgpa = graded.isEmpty ? null : SgpaEngine.calculate(graded);
    final name = profile.displayName.isEmpty ? 'Student' : profile.displayName;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Hello, $name', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(snapshot.semester!.name),
        const SizedBox(height: 24),
        _SoftPanel(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PROJECTED SGPA',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sgpa?.toStringAsFixed(2) ?? 'No marks yet',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                'From your entered marks',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SoftPanel(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const _IconWell(icon: Icons.calendar_month_outlined, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Academic planning',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Timetable, attendance, tasks, habits, notes, and calendar.',
                    ),
                  ],
                ),
              ),
              _IconWellButton(
                onPressed: onOpenPlanning,
                icon: Icons.arrow_forward,
                tooltip: 'Open planning',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Subjects', style: Theme.of(context).textTheme.titleLarge),
            _IconWellButton(
              onPressed: onAddSubject,
              icon: Icons.add,
              tooltip: 'Add subject',
            ),
          ],
        ),
        if (snapshot.subjects.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Add your first subject to begin.'),
          ),
        for (final subject in snapshot.subjects)
          _SoftPanel(
            inset: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        subject.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      subject.percentage
                              ?.toStringAsFixed(0)
                              .replaceAllMapped(RegExp(r'$'), (_) => '%') ??
                          'No marks',
                    ),
                  ],
                ),
                if (subject.code != null) Text(subject.code!),
                Text('${subject.credits.toStringAsFixed(1)} credits'),
                const SizedBox(height: 12),
                for (final assessment in subject.assessments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${assessment.title}: ${assessment.obtainedMarks?.toStringAsFixed(0) ?? '-'} / ${assessment.maxMarks.toStringAsFixed(0)} (${assessment.weightPct.toStringAsFixed(0)}%)',
                    ),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => onAddAssessment(subject),
                    icon: const Icon(Icons.add),
                    label: const Text('Add assessment'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<String?> _textPrompt({
  required BuildContext context,
  required String title,
  required String label,
  String? initialValue,
}) async {
  final controller = TextEditingController(text: initialValue);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  return value == null || value.isEmpty ? null : value;
}

class _SubjectValues {
  const _SubjectValues({
    required this.name,
    required this.code,
    required this.credits,
  });

  final String name;
  final String? code;
  final double credits;
}

Future<_SubjectValues?> _subjectPrompt(BuildContext context) async {
  final name = TextEditingController();
  final code = TextEditingController();
  final credits = TextEditingController(text: '3');
  final values = await showDialog<_SubjectValues>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add subject'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Subject name'),
          ),
          TextField(
            controller: code,
            decoration: const InputDecoration(
              labelText: 'Subject code (optional)',
            ),
          ),
          TextField(
            controller: credits,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Credits'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final parsedCredits = double.tryParse(credits.text);
            if (name.text.trim().isEmpty ||
                parsedCredits == null ||
                parsedCredits <= 0) {
              return;
            }
            Navigator.pop(
              context,
              _SubjectValues(
                name: name.text.trim(),
                code: code.text.trim(),
                credits: parsedCredits,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
  name.dispose();
  code.dispose();
  credits.dispose();
  return values;
}

class _AssessmentValues {
  const _AssessmentValues({
    required this.title,
    required this.weightPct,
    required this.maxMarks,
    required this.obtainedMarks,
  });

  final String title;
  final double weightPct;
  final double maxMarks;
  final double? obtainedMarks;
}

Future<_AssessmentValues?> _assessmentPrompt(
  BuildContext context,
  String subjectName,
) async {
  final title = TextEditingController();
  final weight = TextEditingController(text: '100');
  final max = TextEditingController(text: '100');
  final obtained = TextEditingController();
  final values = await showDialog<_AssessmentValues>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Add assessment to $subjectName'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Assessment title'),
            ),
            TextField(
              controller: weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Weight percent'),
            ),
            TextField(
              controller: max,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Maximum marks'),
            ),
            TextField(
              controller: obtained,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Marks obtained (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final parsedWeight = double.tryParse(weight.text);
            final parsedMax = double.tryParse(max.text);
            final parsedObtained = obtained.text.trim().isEmpty
                ? null
                : double.tryParse(obtained.text);
            if (title.text.trim().isEmpty ||
                parsedWeight == null ||
                parsedWeight <= 0 ||
                parsedMax == null ||
                parsedMax <= 0 ||
                (obtained.text.trim().isNotEmpty && parsedObtained == null)) {
              return;
            }
            Navigator.pop(
              context,
              _AssessmentValues(
                title: title.text.trim(),
                weightPct: parsedWeight,
                maxMarks: parsedMax,
                obtainedMarks: parsedObtained,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
  title.dispose();
  weight.dispose();
  max.dispose();
  obtained.dispose();
  return values;
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({required this.child, this.padding, this.inset = false});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).scaffoldBackgroundColor;
    final shadow = (dark ? _darkShadow : _shadowDark).withValues(
      alpha: inset ? .58 : .7,
    );
    final highlight = (dark ? const Color(0xff4b5b6c) : Colors.white)
        .withValues(alpha: dark ? .32 : .55);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: shadow,
            offset: inset ? const Offset(6, 6) : const Offset(9, 9),
            blurRadius: inset ? 10 : 16,
            spreadRadius: inset ? -4 : 0,
          ),
          BoxShadow(
            color: highlight,
            offset: inset ? const Offset(-6, -6) : const Offset(-9, -9),
            blurRadius: inset ? 10 : 16,
            spreadRadius: inset ? -4 : 0,
          ),
        ],
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({required this.icon, required this.size});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: (dark ? _darkShadow : _shadowDark).withValues(alpha: .7),
            offset: const Offset(5, 5),
            blurRadius: 10,
          ),
          BoxShadow(
            color: (dark ? const Color(0xff4b5b6c) : Colors.white).withValues(
              alpha: dark ? .32 : .58,
            ),
            offset: const Offset(-5, -5),
            blurRadius: 10,
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _IconWellButton extends StatelessWidget {
  const _IconWellButton({
    required this.onPressed,
    required this.icon,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(17),
          child: _IconWell(icon: icon, size: 23),
        ),
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onPressed, required this.child});

  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 52,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        disabledBackgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: .36),
      ),
      child: child,
    ),
  );
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const _IconWell(icon: Icons.school_outlined, size: 25),
      const SizedBox(width: 12),
      Text(
        'CourseCraft',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    ],
  );
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.school_outlined, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8),
      const Text('CourseCraft'),
    ],
  );
}

class _SoftLoadingIndicator extends StatelessWidget {
  const _SoftLoadingIndicator();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: CircularProgressIndicator(
      color: Theme.of(context).colorScheme.primary,
      strokeWidth: 4,
    ),
  );
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    final scope = ThemeScope.of(context);
    final label = scope.isDark ? 'Use light theme' : 'Use dark theme';
    return IconButton(
      onPressed: scope.onToggle,
      tooltip: label,
      icon: Icon(
        scope.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
    );
  }
}
