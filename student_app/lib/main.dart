import 'package:dio/dio.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'theme.dart';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000/api/v1',
);
const forest = AppColors.forest;
const teal = AppColors.teal;
const mint = AppColors.mint;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudentApp());
}

class Api {
  Api()
    : dio = Dio(
        BaseOptions(
          baseUrl: apiBaseUrl,
          headers: {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: 'student_token');
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
      ),
    );
  }
  final Dio dio;
  final storage = const FlutterSecureStorage(aOptions: AndroidOptions());
  Future<bool> hasToken() async =>
      await storage.read(key: 'student_token') != null;
  Future<void> login(String email, String password) async {
    final response = await dio.post(
      '/student/login',
      data: {
        'email': email,
        'password': password,
        'device_name': 'schoolos-student-app',
      },
    );
    await storage.write(
      key: 'student_token',
      value: response.data['data']['token'],
    );
  }

  Future<Map<String, dynamic>> dashboard() async {
    try {
      final value = Map<String, dynamic>.from(
        (await dio.get('/student/dashboard')).data['data'],
      );
      value['_offline'] = false;
      await storage.write(
        key: 'student_dashboard_cache',
        value: jsonEncode(value),
      );
      await storage.write(
        key: 'student_dashboard_cached_at',
        value: DateTime.now().toIso8601String(),
      );
      return value;
    } on DioException catch (error) {
      final cached = await storage.read(key: 'student_dashboard_cache');
      if (cached == null ||
          (error.type != DioExceptionType.connectionError &&
              error.type != DioExceptionType.connectionTimeout &&
              error.type != DioExceptionType.receiveTimeout)) {
        rethrow;
      }
      final value = Map<String, dynamic>.from(jsonDecode(cached));
      value['_offline'] = true;
      value['_cached_at'] = await storage.read(
        key: 'student_dashboard_cached_at',
      );
      return value;
    }
  }

  Future<void> logout() async {
    try {
      await dio.post('/student/logout');
    } finally {
      await storage.delete(key: 'student_token');
    }
  }
}

final api = Api();

class StudentApp extends StatefulWidget {
  const StudentApp({super.key});
  @override
  State<StudentApp> createState() => _StudentAppState();
}

class _StudentAppState extends State<StudentApp> {
  bool? signedIn;
  @override
  void initState() {
    super.initState();
    api.hasToken().then(
      (value) => mounted ? setState(() => signedIn = value) : null,
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SchoolOS Student',
    theme: schoolTheme(),
    home: signedIn == null
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : signedIn!
        ? StudentShell(onLogout: () => setState(() => signedIn = false))
        : LoginScreen(onLogin: () => setState(() => signedIn = true)),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});
  final VoidCallback onLogin;
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  bool obscure = true;
  String? error;
  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await api.login(email.text.trim(), password.text);
      widget.onLogin();
    } on DioException catch (e) {
      setState(
        () => error = e.response?.data?['message'] ?? 'Unable to sign in.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Positioned(
          right: -80,
          top: -90,
          child: Container(
            width: 240,
            height: 240,
            decoration: const BoxDecoration(
              color: AppColors.softMint,
              shape: BoxShape.circle,
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Image.asset('logo.png', fit: BoxFit.contain),
                      ),
                      const Spacer(),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.school_outlined,
                          color: AppColors.forest,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  const Text(
                    'Welcome\nback.',
                    style: TextStyle(
                      fontSize: 42,
                      height: 1.02,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.4,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Sign in to view your results, homework, attendance and upcoming school activities.',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: AppColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 38),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(
                      hintText: 'Student login email',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: password,
                    obscureText: obscure,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => busy ? null : submit(),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => obscure = !obscure),
                        icon: Icon(
                          obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Sign in'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 19),
                            ],
                          ),
                  ),
                  const SizedBox(height: 22),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 15, color: AppColors.teal),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Your school administrator provides your login email and temporary password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class StudentShell extends StatefulWidget {
  const StudentShell({super.key, required this.onLogout});
  final VoidCallback onLogout;
  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int page = 0;
  late Future<Map<String, dynamic>> future = api.dashboard();
  Future<void> refresh() async {
    final next = api.dashboard();
    setState(() => future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off),
                        TextButton(
                          onPressed: refresh,
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            );
          }
          final data = snapshot.data!;
          final pages = [
            _Home(data: data),
            _Results(items: data['results'] as List? ?? []),
            _Homework(items: data['homework'] as List? ?? []),
            _More(
              data: data,
              onLogout: () async {
                await api.logout();
                widget.onLogout();
              },
            ),
          ];
          return Column(
            children: [
              if (data['_offline'] == true)
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF3CD),
                  padding: const EdgeInsets.all(9),
                  child: Text(
                    'Offline · showing saved data from ${data['_cached_at'] ?? 'your last sync'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Expanded(
                child: RefreshIndicator(onRefresh: refresh, child: pages[page]),
              ),
            ],
          );
        },
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: page,
      onDestinationSelected: (value) => setState(() => page = value),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.auto_graph), label: 'Results'),
        NavigationDestination(
          icon: Icon(Icons.assignment_outlined),
          label: 'Homework',
        ),
        NavigationDestination(icon: Icon(Icons.grid_view), label: 'More'),
      ],
    ),
  );
}

class _Home extends StatelessWidget {
  const _Home({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final student = data['student'] as Map;
    final attendance = data['attendance'] as List? ?? [];
    final events = data['events'] as List? ?? [];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hello, ${student['name'].toString().split(' ').first}',
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w900, color: forest),
        ),
        Text('${student['class'] ?? ''} · ${student['admission_number']}'),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _Metric(label: 'Average', value: '${data['average']}%'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Metric(
                label: 'Latest attendance',
                value: attendance.isEmpty
                    ? '—'
                    : '${attendance.first['status']}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Upcoming events',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        ...events.map(
          (event) => Card(
            child: ListTile(
              leading: const Icon(Icons.event, color: teal),
              title: Text('${event['title']}'),
              subtitle: Text('${event['location'] ?? 'School event'}'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: forest,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: mint)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _Results extends StatelessWidget {
  const _Results({required this.items});
  final List items;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'My results',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w900, color: forest),
      ),
      const SizedBox(height: 16),
      if (items.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No published results yet.'),
          ),
        ),
      ...items.map(
        (r) => Card(
          child: ListTile(
            title: Text('${r['subject']?['name'] ?? r['exam_type']}'),
            subtitle: Text('${r['term'] ?? ''} · ${r['grade'] ?? ''}'),
            trailing: Text(
              '${r['score']}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: forest,
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _Homework extends StatelessWidget {
  const _Homework({required this.items});
  final List items;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Homework',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w900, color: forest),
      ),
      const SizedBox(height: 16),
      if (items.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No homework due.'),
          ),
        ),
      ...items.map(
        (h) => Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${h['title']}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${h['subject']?['name'] ?? 'Subject'} · due ${_date(h['due_at'])}',
                ),
                const SizedBox(height: 8),
                Text('${h['instructions']}'),
              ],
            ),
          ),
        ),
      ),
    ],
  );
  static String _date(dynamic value) => value == null
      ? '—'
      : DateFormat('MMM d, h:mm a').format(DateTime.parse('$value').toLocal());
}

class _More extends StatelessWidget {
  const _More({required this.data, required this.onLogout});
  final Map<String, dynamic> data;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'More',
        style: Theme.of(context).textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w900, color: forest),
      ),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.quiz_outlined),
        title: const Text('Available CBT exams'),
        trailing: Text('${(data['exams'] as List? ?? []).length}'),
      ),
      ...(data['exams'] as List? ?? []).map(
        (exam) => Card(
          child: ListTile(
            leading: const Icon(Icons.play_circle_outline, color: teal),
            title: Text('${exam['title']}'),
            subtitle: Text(
              '${exam['subject']?['name'] ?? 'Assessment'} · Code ${exam['access_code'] ?? 'provided by school'}',
            ),
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: const Text('Attendance history'),
        trailing: Text('${(data['attendance'] as List? ?? []).length} records'),
      ),
      const Divider(),
      ListTile(
        onTap: onLogout,
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Sign out'),
      ),
    ],
  );
}
