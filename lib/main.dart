import 'dart:async';

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const config = AppConfig.fromEnvironment();
  if (config.isSupabaseConfigured) {
    await SupabaseService.initialize(config);
  }
  runApp(CourseCraftApp(config: config));
}

class CourseCraftApp extends StatelessWidget {
  const CourseCraftApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'CourseCraft',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _accent,
            brightness: Brightness.light,
            surface: _surface,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: _surface,
          textTheme: ThemeData.light().textTheme.apply(
            bodyColor: _ink,
            displayColor: _ink,
            fontFamily: 'sans-serif',
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: _surface,
            foregroundColor: _ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            labelStyle: const TextStyle(color: _muted),
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
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
            ),
            elevation: 0,
          ),
        ),
        home: config.isSupabaseConfigured
            ? AuthGate(repository: AuthRepository(Supabase.instance.client))
            : const ConfigurationScreen(),
      ),
    );
  }
}

class ConfigurationScreen extends StatelessWidget {
  const ConfigurationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
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
                          decoration: const InputDecoration(labelText: 'Name'),
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
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (value) =>
                            value == null || !value.contains('@')
                            ? 'Enter a valid email.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                        validator: (value) => value == null || value.length < 8
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
                              : 'New to CourseCraft? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
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
          return _AcademicDashboard(
            profile: widget.profile,
            snapshot: data,
            onAddSubject: () => _addSubject(data.semester!),
            onAddAssessment: (subject) => _addAssessment(subject),
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

class _AcademicDashboard extends StatelessWidget {
  const _AcademicDashboard({
    required this.profile,
    required this.snapshot,
    required this.onAddSubject,
    required this.onAddAssessment,
  });

  final AppProfile profile;
  final AcademicSnapshot snapshot;
  final VoidCallback onAddSubject;
  final Future<void> Function(AcademicSubject) onAddAssessment;

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
              const Text(
                'PROJECTED SGPA',
                style: TextStyle(
                  color: _accent,
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
              const Text(
                'From your entered marks',
                style: TextStyle(color: _muted),
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
    final shadow = _shadowDark.withValues(alpha: inset ? .48 : .6);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: shadow,
            offset: inset ? const Offset(6, 6) : const Offset(9, 9),
            blurRadius: inset ? 10 : 16,
            spreadRadius: inset ? -4 : 0,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: .55),
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
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(17),
      boxShadow: [
        BoxShadow(
          color: _shadowDark.withValues(alpha: .55),
          offset: const Offset(5, 5),
          blurRadius: 10,
        ),
        BoxShadow(
          color: Colors.white.withValues(alpha: .58),
          offset: const Offset(-5, -5),
          blurRadius: 10,
        ),
      ],
    ),
    child: Icon(icon, size: size, color: _accent),
  );
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
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _accent.withValues(alpha: .45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: _accent.withValues(alpha: .36),
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
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.school_outlined, color: _accent),
      SizedBox(width: 8),
      Text('CourseCraft'),
    ],
  );
}

class _SoftLoadingIndicator extends StatelessWidget {
  const _SoftLoadingIndicator();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 48,
    height: 48,
    child: CircularProgressIndicator(color: _accent, strokeWidth: 4),
  );
}
