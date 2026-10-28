import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await FplNotifications.init();

  runApp(const FplArabiaApp());
}

// ============================================================
// THEME
// ============================================================

class AppColors {
  static const purple = Color(0xFF37003C);
  static const green = Color(0xFF00FF87);
  static const cyan = Color(0xFF04F5FF);
  static const magenta = Color(0xFFE90052);
  static const background = Color(0xFF0D1117);
  static const card = Color(0xFF171D27);
  static const muted = Color(0xFF929BAA);
}

class FplArabiaApp extends StatelessWidget {
  const FplArabiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FPL Arabia',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.green,
          secondary: AppColors.cyan,
          surface: AppColors.card,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: AppColors.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: MainScreen(),
      ),
    );
  }
}

// ============================================================
// NOTIFICATIONS
// ============================================================

class FplNotifications {
  static final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(android: android);

    try {
      await plugin.initialize(settings);
    } catch (_) {}
  }

  static Future<void> requestPermission() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();
  }

  static Future<void> show(
    String title,
    String body,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'fpl_arabia',
        'FPL Arabia',
        channelDescription: 'تنبيهات تطبيق فانتازي الدوري الإنجليزي',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    await plugin.show(
      1,
      title,
      body,
      details,
    );
  }
}

// ============================================================
// API SERVICE
// ============================================================

class FplApi {
  static const String base =
      'https://fantasy.premierleague.com/api';

  static Future<Map<String, dynamic>> getBootstrap() async {
    final response = await http
        .get(
          Uri.parse('$base/bootstrap-static/'),
          headers: const {
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception(
        'تعذر جلب بيانات اللاعبين. HTTP ${response.statusCode}',
      );
    }

    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  static Future<List<dynamic>> getFixtures() async {
    final response = await http
        .get(Uri.parse('$base/fixtures/'))
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('تعذر جلب المباريات');
    }

    return jsonDecode(utf8.decode(response.bodyBytes)) as List;
  }

  static Future<Map<String, dynamic>> getLive(int gameweek) async {
    final response = await http
        .get(Uri.parse('$base/event/$gameweek/live/'))
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('تعذر جلب النقاط المباشرة');
    }

    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }

  static Future<Map<String, dynamic>> getPlayerSummary(
    int playerId,
  ) async {
    final response = await http
        .get(Uri.parse('$base/element-summary/$playerId/'))
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) {
      throw Exception('تعذر جلب إحصائيات اللاعب');
    }

    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map,
    );
  }
}

// ============================================================
// HELPERS
// ============================================================

String textOf(dynamic value, [String fallback = '—']) {
  if (value == null) return fallback;
  return value.toString();
}

double numberOf(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int intOf(dynamic value) {
  return numberOf(value).round();
}

String moneyOf(dynamic value) {
  return '£${(numberOf(value) / 10).toStringAsFixed(1)}m';
}

String positionOf(dynamic value) {
  switch (intOf(value)) {
    case 1:
      return 'حارس';
    case 2:
      return 'دفاع';
    case 3:
      return 'وسط';
    case 4:
      return 'هجوم';
    default:
      return 'غير محدد';
  }
}

String playerStatus(dynamic status) {
  switch (textOf(status)) {
    case 'a':
      return 'متاح';
    case 'd':
      return 'شكوك حول المشاركة';
    case 'i':
      return 'مصاب';
    case 's':
      return 'موقوف';
    case 'u':
      return 'غير متاح';
    case 'n':
      return 'غير معروف';
    default:
      return 'الحالة غير محددة';
  }
}

Color statusColor(dynamic status) {
  switch (textOf(status)) {
    case 'a':
      return AppColors.green;
    case 'd':
      return Colors.orange;
    case 'i':
    case 's':
    case 'u':
      return AppColors.magenta;
    default:
      return AppColors.muted;
  }
}

String fixtureDate(dynamic value) {
  if (value == null) return 'لم يحدد الموعد';

  final date = DateTime.tryParse(value.toString());

  if (date == null) return 'لم يحدد الموعد';

  final local = date.toLocal();

  String two(int n) => n.toString().padLeft(2, '0');

  return '${two(local.day)}/${two(local.month)} '
      '${two(local.hour)}:${two(local.minute)}';
}

// ============================================================
// DATA REPOSITORY
// ============================================================

class FplRepository {
  Map<String, dynamic>? bootstrap;
  List<dynamic> fixtures = [];
  Map<int, int> livePoints = {};

  DateTime? lastUpdated;

  List<dynamic> get players =>
      (bootstrap?['elements'] as List?) ?? [];

  List<dynamic> get teams =>
      (bootstrap?['teams'] as List?) ?? [];

  List<dynamic> get events =>
      (bootstrap?['events'] as List?) ?? [];

  List<dynamic> get positions =>
      (bootstrap?['element_types'] as List?) ?? [];

  Map<String, dynamic>? get currentEvent {
    for (final event in events) {
      if (event is Map && event['is_current'] == true) {
        return Map<String, dynamic>.from(event);
      }
    }

    return null;
  }

  Map<String, dynamic>? get nextEvent {
    for (final event in events) {
      if (event is Map && event['is_next'] == true) {
        return Map<String, dynamic>.from(event);
      }
    }

    return null;
  }

  int get activeGameweek {
    final current = currentEvent;
    if (current != null) return intOf(current['id']);

    final next = nextEvent;
    if (next != null) return intOf(next['id']);

    return 1;
  }

  String teamName(dynamic teamId) {
    for (final team in teams) {
      if (intOf(team['id']) == intOf(teamId)) {
        return textOf(team['name']);
      }
    }
    return 'نادي غير معروف';
  }

  Map<String, dynamic>? teamData(dynamic teamId) {
    for (final team in teams) {
      if (intOf(team['id']) == intOf(teamId)) {
        return Map<String, dynamic>.from(team);
      }
    }
    return null;
  }

  String playerName(Map player) {
    return '${textOf(player['first_name'], '')} '
            '${textOf(player['second_name'], '')}'
        .trim();
  }

  String playerPhoto(Map player) {
    final photo = textOf(player['photo'], '');

    if (photo.isEmpty) return '';

    final filename = photo.replaceAll('.jpg', '.png');

    return 'https://resources.premierleague.com/premierleague/photos/players/110x140/$filename';
  }

  String clubLogo(dynamic teamId) {
    final team = teamData(teamId);

    if (team == null) return '';

    final code = textOf(team['code'], '');

    if (code.isEmpty) return '';

    return 'https://resources.premierleague.com/premierleague/badges/70/t$code.png';
  }

  Future<void> refresh() async {
    final data = await FplApi.getBootstrap();

    bootstrap = data;

    fixtures = await FplApi.getFixtures();

    livePoints = {};

    try {
      final live = await FplApi.getLive(activeGameweek);
      final elements = (live['elements'] as List?) ?? [];

      for (final item in elements) {
        if (item is! Map) continue;

        final id = intOf(item['id']);
        final stats = item['stats'];

        if (stats is Map) {
          livePoints[id] = intOf(stats['total_points']);
        }
      }
    } catch (_) {
      // تعذر جلب النقاط المباشرة لا يمنع عرض بقية البيانات.
    }

    lastUpdated = DateTime.now();
  }
}

// ============================================================
// MAIN SCREEN
// ============================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final FplRepository repository = FplRepository();

  int selectedTab = 0;
  bool loading = true;
  String? error;
  Timer? refreshTimer;

  final List<String> titles = const [
    'FPL Arabia',
    'اللاعبون',
    'المباريات',
    'الترتيب',
    'المفضلة',
  ];

  @override
  void initState() {
    super.initState();
    loadData();

    // تحديث أثناء فتح التطبيق كل 5 دقائق.
    refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => loadData(silent: true),
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      await repository.refresh();

      if (!mounted) return;

      setState(() {
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(
        repository: repository,
        loading: loading,
        error: error,
        onRefresh: () => loadData(),
        onNavigate: (index) {
          setState(() => selectedTab = index);
        },
      ),
      PlayersPage(repository: repository),
      FixturesPage(repository: repository),
      RankingsPage(repository: repository),
      FavoritesPage(repository: repository),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(
              Icons.sports_soccer,
              color: AppColors.green,
            ),
            const SizedBox(width: 9),
            Text(
              titles[selectedTab],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: loading ? null : () => loadData(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'الإعدادات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    onRefresh: () => loadData(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: loading && repository.players.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.green,
              ),
            )
          : IndexedStack(
              index: selectedTab,
              children: pages,
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.green.withValues(alpha: 0.15),
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'اللاعبون',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'المباريات',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'الترتيب',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: 'المفضلة',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// COMMON WIDGETS
// ============================================================

Widget sectionTitle(String title, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}

Widget infoCard({
  required String title,
  required String value,
  IconData icon = Icons.analytics_outlined,
  Color color = AppColors.green,
}) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget playerAvatar(FplRepository repo, Map player) {
  final url = repo.playerPhoto(player);

  return CircleAvatar(
    radius: 25,
    backgroundColor: AppColors.purple,
    child: ClipOval(
      child: url.isEmpty
          ? const Icon(Icons.person)
          : Image.network(
              url,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person),
            ),
    ),
  );
}

// ============================================================
// HOME
// ============================================================

class HomePage extends StatelessWidget {
  final FplRepository repository;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;
  final ValueChanged<int> onNavigate;

  const HomePage({
    super.key,
    required this.repository,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    if (repository.bootstrap == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off,
                size: 60,
                color: AppColors.magenta,
              ),
              const SizedBox(height: 16),
              const Text(
                'تعذر تحميل بيانات FPL',
                style: TextStyle(fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                error ?? 'تحقق من اتصال الإنترنت ثم حاول مجددًا.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final players = repository.players;
    final events = repository.events;
    final current = repository.currentEvent;
    final next = repository.nextEvent;

    final sorted = List<dynamic>.from(players);

    sorted.sort(
      (a, b) => intOf(b['total_points'])
          .compareTo(intOf(a['total_points'])),
    );

    final topPlayers = sorted.take(5).toList();

    final deadline = current?['deadline_time'] ?? next?['deadline_time'];

    final clubs = repository.teams.length;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  AppColors.purple,
                  Color(0xFF20283B),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مرحبًا بك في FPL Arabia',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تابع اللاعبين والمباريات والإحصائيات الفعلية.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        current != null
                            ? 'الجولة الحالية: ${textOf(current['name'])}'
                            : next != null
                                ? 'الجولة القادمة: ${textOf(next['name'])}'
                                : 'الجولة غير محددة',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (deadline != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'موعد الإغلاق: ${fixtureDate(deadline)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),

          sectionTitle('ملخص الموسم'),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.45,
            children: [
              infoCard(
                title: 'عدد اللاعبين',
                value: '${players.length}',
                icon: Icons.people,
              ),
              infoCard(
                title: 'الأندية',
                value: '$clubs',
                icon: Icons.shield,
                color: AppColors.cyan,
              ),
              infoCard(
                title: 'الجولات',
                value: '${events.length}',
                icon: Icons.calendar_month,
                color: Colors.orange,
              ),
              infoCard(
                title: 'مدربو FPL',
                value: textOf(
                  repository.bootstrap?['total_players'],
                  '—',
                ),
                icon: Icons.groups,
                color: AppColors.magenta,
              ),
            ],
          ),

          sectionTitle('أعلى اللاعبين نقاطًا'),

          ...topPlayers.map((player) {
            final p = Map<String, dynamic>.from(player);

            return PlayerTile(
              repository: repository,
              player: p,
            );
          }),

          sectionTitle('الوصول السريع'),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.people),
                label: const Text('اللاعبون'),
                onPressed: () => onNavigate(1),
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_month),
                label: const Text('المباريات'),
                onPressed: () => onNavigate(2),
              ),
              ActionChip(
                avatar: const Icon(Icons.leaderboard),
                label: const Text('الترتيب'),
                onPressed: () => onNavigate(3),
              ),
              ActionChip(
                avatar: const Icon(Icons.star),
                label: const Text('المفضلة'),
                onPressed: () => onNavigate(4),
              ),
            ],
          ),

          if (repository.lastUpdated != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'آخر تحديث: ${fixtureDate(repository.lastUpdated!.toIso8601String())}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// FAVORITES SERVICE
// ============================================================

class FavoritesService {
  static const key = 'fpl_favorites';

  static Future<Set<int>> getAll() async {
    final prefs = await SharedPreferences.getInstance();

    return (prefs.getStringList(key) ?? [])
        .map((e) => int.tryParse(e))
        .whereType<int>()
        .toSet();
  }

  static Future<void> toggle(int playerId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(key) ?? []).toSet();

    final id = playerId.toString();

    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }

    await prefs.setStringList(key, ids.toList());
  }
}

// ============================================================
// PLAYER TILE
// ============================================================

class PlayerTile extends StatefulWidget {
  final FplRepository repository;
  final Map<String, dynamic> player;

  const PlayerTile({
    super.key,
    required this.repository,
    required this.player,
  });

  @override
  State<PlayerTile> createState() => _PlayerTileState();
}

class _PlayerTileState extends State<PlayerTile> {
  bool favorite = false;

  @override
  void initState() {
    super.initState();
    checkFavorite();
  }

  Future<void> checkFavorite() async {
    final ids = await FavoritesService.getAll();

    if (!mounted) return;

    setState(() {
      favorite = ids.contains(intOf(widget.player['id']));
    });
  }

  Future<void> toggleFavorite() async {
    await FavoritesService.toggle(intOf(widget.player['id']));
    await checkFavorite();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final repo = widget.repository;

    final teamId = p['team'];
    final points = repo.livePoints[intOf(p['id'])];

    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        leading: playerAvatar(repo, p),
        title: Text(
          repo.playerName(p),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${repo.teamName(teamId)} • ${positionOf(p['element_type'])}',
            ),
            const SizedBox(height: 3),
            Text(
              '${moneyOf(p['now_cost'])}  •  الفورمة ${textOf(p['form'], '0')}',
              style: const TextStyle(color: AppColors.muted),
            ),
            Text(
              playerStatus(p['status']),
              style: TextStyle(
                color: statusColor(p['status']),
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${intOf(p['total_points'])}',
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              points == null ? 'نقطة' : 'مباشر: $points',
              style: const TextStyle(fontSize: 10),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: toggleFavorite,
              icon: Icon(
                favorite ? Icons.star : Icons.star_border,
                color: favorite ? Colors.amber : AppColors.muted,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerDetailsPage(
                repository: repo,
                player: p,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// PLAYERS
// ============================================================

class PlayersPage extends StatefulWidget {
  final FplRepository repository;

  const PlayersPage({
    super.key,
    required this.repository,
  });

  @override
  State<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends State<PlayersPage> {
  final TextEditingController search = TextEditingController();

  String position = 'الكل';
  String sort = 'النقاط';
  int? clubId;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;

    var players = repo.players
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((p) {
      final query = search.text.trim().toLowerCase();

      final name = repo.playerName(p).toLowerCase();
      final team = repo.teamName(p['team']).toLowerCase();

      final matchesSearch =
          query.isEmpty || name.contains(query) || team.contains(query);

      final pos = position == 'الكل' ||
          positionOf(p['element_type']) == position;

      final club = clubId == null || intOf(p['team']) == clubId;

      return matchesSearch && pos && club;
    }).toList();

    switch (sort) {
      case 'السعر':
        players.sort(
          (a, b) => intOf(b['now_cost'])
              .compareTo(intOf(a['now_cost'])),
        );
        break;
      case 'الفورمة':
        players.sort(
          (a, b) => numberOf(b['form'])
              .compareTo(numberOf(a['form'])),
        );
        break;
      case 'الملكية':
        players.sort(
          (a, b) => numberOf(b['selected_by_percent'])
              .compareTo(numberOf(a['selected_by_percent'])),
        );
        break;
      default:
        players.sort(
          (a, b) => intOf(b['total_points'])
              .compareTo(intOf(a['total_points'])),
        );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'ابحث عن لاعب أو نادٍ...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              for (final p in ['الكل', 'حارس', 'دفاع', 'وسط', 'هجوم'])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(p),
                    selected: position == p,
                    onSelected: (_) {
                      setState(() => position = p);
                    },
                  ),
                ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text('ترتيب حسب: '),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<String>(
                  value: sort,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'النقاط',
                      child: Text('النقاط'),
                    ),
                    DropdownMenuItem(
                      value: 'السعر',
                      child: Text('السعر'),
                    ),
                    DropdownMenuItem(
                      value: 'الفورمة',
                      child: Text('الفورمة'),
                    ),
                    DropdownMenuItem(
                      value: 'الملكية',
                      child: Text('الملكية'),
                    ),
                  ],
                  onChanged: (v) => setState(() => sort = v ?? 'النقاط'),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<int?>(
            value: clubId,
            isExpanded: true,
            hint: const Text('جميع الأندية'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('جميع الأندية'),
              ),
              ...repo.teams.map((team) {
                return DropdownMenuItem<int?>(
                  value: intOf(team['id']),
                  child: Text(textOf(team['name'])),
                );
              }),
            ],
            onChanged: (v) => setState(() => clubId = v),
          ),
        ),

        Expanded(
          child: players.isEmpty
              ? const Center(child: Text('لا توجد نتائج'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: players.length,
                  itemBuilder: (_, i) {
                    return PlayerTile(
                      repository: repo,
                      player: players[i],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================
// PLAYER DETAILS AND ANALYSIS
// ============================================================

class PlayerDetailsPage extends StatefulWidget {
  final FplRepository repository;
  final Map<String, dynamic> player;

  const PlayerDetailsPage({
    super.key,
    required this.repository,
    required this.player,
  });

  @override
  State<PlayerDetailsPage> createState() => _PlayerDetailsPageState();
}

class _PlayerDetailsPageState extends State<PlayerDetailsPage> {
  Map<String, dynamic>? summary;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadSummary();
  }

  Future<void> loadSummary() async {
    try {
      final result = await FplApi.getPlayerSummary(
        intOf(widget.player['id']),
      );

      if (!mounted) return;

      setState(() {
        summary = result;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final repo = widget.repository;

    final live = repo.livePoints[intOf(p['id'])];

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل اللاعب'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.purple,
              child: ClipOval(
                child: Image.network(
                  repo.playerPhoto(p),
                  width: 104,
                  height: 104,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.person, size: 55),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              repo.playerName(p),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Center(
            child: Text(
              '${repo.teamName(p['team'])} • ${positionOf(p['element_type'])}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 20),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.45,
            children: [
              infoCard(
                title: 'النقاط الإجمالية',
                value: '${intOf(p['total_points'])}',
              ),
              infoCard(
                title: 'السعر',
                value: moneyOf(p['now_cost']),
                color: AppColors.cyan,
              ),
              infoCard(
                title: 'الفورمة',
                value: textOf(p['form'], '0'),
                color: Colors.orange,
              ),
              infoCard(
                title: 'نقاط المباراة الحية',
                value: live?.toString() ?? 'غير متاحة',
                color: AppColors.magenta,
              ),
              infoCard(
                title: 'الملكية',
                value: '${textOf(p['selected_by_percent'], '0')}%',
              ),
              infoCard(
                title: 'نقاط لكل مباراة',
                value: textOf(p['points_per_game'], '0'),
              ),
            ],
          ),

          sectionTitle('حالة اللاعب'),

          Card(
            child: ListTile(
              leading: Icon(
                Icons.health_and_safety,
                color: statusColor(p['status']),
              ),
              title: Text(playerStatus(p['status'])),
              subtitle: Text(
                textOf(p['news'], 'لا توجد ملاحظات إضافية من FPL'),
              ),
            ),
          ),

          sectionTitle('معلومات إضافية'),

          Card(
            child: Column(
              children: [
                ListTile(
                  title: const Text('الأهداف'),
                  trailing: Text(textOf(p['goals_scored'], '0')),
                ),
                ListTile(
                  title: const Text('التمريرات الحاسمة'),
                  trailing: Text(textOf(p['assists'], '0')),
                ),
                ListTile(
                  title: const Text('الدقائق'),
                  trailing: Text(textOf(p['minutes'], '0')),
                ),
                ListTile(
                  title: const Text('الشباك النظيفة'),
                  trailing: Text(textOf(p['clean_sheets'], '0')),
                ),
                ListTile(
                  title: const Text('النقاط الإضافية'),
                  trailing: Text(textOf(p['bonus'], '0')),
                ),
                ListTile(
                  title: const Text('تغير السعر هذا الموسم'),
                  trailing: Text(
                    '${numberOf(p['cost_change_start']) >= 0 ? '+' : ''}'
                    '${(numberOf(p['cost_change_start']) / 10).toStringAsFixed(1)}m',
                  ),
                ),
              ],
            ),
          ),

          sectionTitle('المباريات السابقة'),

          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (summary != null)
            ...((summary!['history'] as List?) ?? [])
                .reversed
                .take(8)
                .map((match) {
              return Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.sports_soccer,
                    color: AppColors.green,
                  ),
                  title: Text(
                    'الجولة ${textOf(match['round'])}',
                  ),
                  subtitle: Text(
                    'الدقائق: ${textOf(match['minutes'], '0')}'
                    ' • الأهداف: ${textOf(match['goals_scored'], '0')}'
                    ' • التمريرات: ${textOf(match['assists'], '0')}',
                  ),
                  trailing: Text(
                    '${textOf(match['total_points'], '0')} نقطة',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            })
          else
            Text(error ?? 'تعذر تحميل تاريخ اللاعب'),
        ],
      ),
    );
  }
}

// ============================================================
// FIXTURES
// ============================================================

class FixturesPage extends StatefulWidget {
  final FplRepository repository;

  const FixturesPage({
    super.key,
    required this.repository,
  });

  @override
  State<FixturesPage> createState() => _FixturesPageState();
}

class _FixturesPageState extends State<FixturesPage> {
  int? selectedGameweek;

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;

    final gameweeks = repo.events
        .map((e) => intOf(e['id']))
        .where((id) => id > 0)
        .toList();

    final selected = selectedGameweek ?? repo.activeGameweek;

    final fixtures = repo.fixtures.where((f) {
      return intOf(f['event']) == selected;
    }).toList();

    fixtures.sort((a, b) {
      return textOf(a['kickoff_time'], 'z')
          .compareTo(textOf(b['kickoff_time'], 'z'));
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButton<int>(
            value: gameweeks.contains(selected)
                ? selected
                : (gameweeks.isNotEmpty ? gameweeks.first : null),
            isExpanded: true,
            hint: const Text('اختر الجولة'),
            items: gameweeks.map((id) {
              final event = repo.events.firstWhere(
                (e) => intOf(e['id']) == id,
              );

              return DropdownMenuItem<int>(
                value: id,
                child: Text(textOf(event['name'], 'الجولة $id')),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedGameweek = v),
          ),
        ),

        Expanded(
          child: fixtures.isEmpty
              ? const Center(
                  child: Text('لا توجد مباريات مسجلة لهذه الجولة'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: fixtures.length,
                  itemBuilder: (_, index) {
                    final f = fixtures[index];

                    final homeId = f['team_h'];
                    final awayId = f['team_a'];

                    final homeScore = f['team_h_score'];
                    final awayScore = f['team_a_score'];

                    final played = f['finished'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Text(
                              fixtureDate(f['kickoff_time']),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Image.network(
                                        repo.clubLogo(homeId),
                                        width: 38,
                                        height: 38,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.shield),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        repo.teamName(homeId),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  child: Text(
                                    played
                                        ? '${textOf(homeScore, '0')} - ${textOf(awayScore, '0')}'
                                        : 'VS',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Image.network(
                                        repo.clubLogo(awayId),
                                        width: 38,
                                        height: 38,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.shield),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        repo.teamName(awayId),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              played
                                  ? 'انتهت المباراة'
                                  : 'صعوبة FPL: ${textOf(f['team_h_difficulty'])} / ${textOf(f['team_a_difficulty'])}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ============================================================
// PLAYER RANKINGS
// ============================================================

class RankingsPage extends StatefulWidget {
  final FplRepository repository;

  const RankingsPage({
    super.key,
    required this.repository,
  });

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  String ranking = 'النقاط';

  @override
  Widget build(BuildContext context) {
    final repo = widget.repository;

    final players = repo.players
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    switch (ranking) {
      case 'الفورمة':
        players.sort(
          (a, b) => numberOf(b['form'])
              .compareTo(numberOf(a['form'])),
        );
        break;
      case 'الأهداف':
        players.sort(
          (a, b) => intOf(b['goals_scored'])
              .compareTo(intOf(a['goals_scored'])),
        );
        break;
      case 'التمريرات':
        players.sort(
          (a, b) => intOf(b['assists'])
              .compareTo(intOf(a['assists'])),
        );
        break;
      default:
        players.sort(
          (a, b) => intOf(b['total_points'])
              .compareTo(intOf(a['total_points'])),
        );
    }

    final teams = List<dynamic>.from(repo.teams);

    teams.sort(
      (a, b) => textOf(a['name']).compareTo(textOf(b['name'])),
    );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'ترتيب اللاعبين حسب إحصائيات الموسم',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        DropdownButton<String>(
          value: ranking,
          isExpanded: true,
          items: const [
            DropdownMenuItem(
              value: 'النقاط',
              child: Text('إجمالي النقاط'),
            ),
            DropdownMenuItem(
              value: 'الفورمة',
              child: Text('الفورمة'),
            ),
            DropdownMenuItem(
              value: 'الأهداف',
              child: Text('الأهداف'),
            ),
            DropdownMenuItem(
              value: 'التمريرات',
              child: Text('التمريرات الحاسمة'),
            ),
          ],
          onChanged: (v) => setState(() => ranking = v ?? 'النقاط'),
        ),

        ...players.take(50).toList().asMap().entries.map((entry) {
          final index = entry.key + 1;
          final p = entry.value;

          String score;

          switch (ranking) {
            case 'الفورمة':
              score = textOf(p['form'], '0');
              break;
            case 'الأهداف':
              score = textOf(p['goals_scored'], '0');
              break;
            case 'التمريرات':
              score = textOf(p['assists'], '0');
              break;
            default:
              score = textOf(p['total_points'], '0');
          }

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.purple,
                child: Text('$index'),
              ),
              title: Text(widget.repository.playerName(p)),
              subtitle: Text(
                '${repo.teamName(p['team'])} • ${positionOf(p['element_type'])}',
              ),
              trailing: Text(
                score,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayerDetailsPage(
                      repository: repo,
                      player: p,
                    ),
                  ),
                );
              },
            ),
          );
        }),

        sectionTitle('الأندية المشاركة'),

        ...teams.map((team) {
          final t = Map<String, dynamic>.from(team);

          return Card(
            child: ListTile(
              leading: Image.network(
                repo.clubLogo(t['id']),
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.shield),
              ),
              title: Text(textOf(t['name'])),
              subtitle: Text(
                'قوة الهجوم: ${textOf(t['strength_attack_home'], '—')}'
                ' • قوة الدفاع: ${textOf(t['strength_defence_home'], '—')}',
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ============================================================
// FAVORITES
// ============================================================

class FavoritesPage extends StatefulWidget {
  final FplRepository repository;

  const FavoritesPage({
    super.key,
    required this.repository,
  });

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  Set<int> ids = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final result = await FavoritesService.getAll();

    if (!mounted) return;

    setState(() {
      ids = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final players = widget.repository.players
        .where((p) => ids.contains(intOf(p['id'])))
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();

    return RefreshIndicator(
      onRefresh: loadFavorites,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : players.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 100),
                    Icon(
                      Icons.star_border,
                      size: 70,
                      color: AppColors.muted,
                    ),
                    SizedBox(height: 16),
                    Center(
                      child: Text(
                        'لم تضف أي لاعب إلى المفضلة بعد',
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: players.length,
                  itemBuilder: (_, i) {
                    return PlayerTile(
                      repository: widget.repository,
                      player: players[i],
                    );
                  },
                ),
    );
  }
}

// ============================================================
// SETTINGS
// ============================================================

class SettingsPage extends StatefulWidget {
  final VoidCallback onRefresh;

  const SettingsPage({
    super.key,
    required this.onRefresh,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool deadlineReminder = false;
  bool priceReminder = false;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      deadlineReminder = prefs.getBool('deadline_reminder') ?? false;
      priceReminder = prefs.getBool('price_reminder') ?? false;
    });
  }

  Future<void> saveSetting(
    String key,
    bool value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'التنبيهات',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          SwitchListTile(
            title: const Text('تذكير موعد الجولة'),
            subtitle: const Text(
              'تفعيل الخيار يحفظ تفضيلك؛ لم يُضبط منبه زمني بعد.',
            ),
            value: deadlineReminder,
            onChanged: (value) async {
              await FplNotifications.requestPermission();
              await saveSetting('deadline_reminder', value);

              if (!mounted) return;

              setState(() => deadlineReminder = value);

              if (value) {
                await FplNotifications.show(
                  'FPL Arabia',
                  'تم تفعيل تفضيل تذكير موعد الجولة.',
                );
              }
            },
          ),

          SwitchListTile(
            title: const Text('تذكير تغير الأسعار'),
            subtitle: const Text(
              'حفظ التفضيل فقط؛ رصد تغير الأسعار تلقائيًا يحتاج إلى مراقبة مستمرة.',
            ),
            value: priceReminder,
            onChanged: (value) async {
              await saveSetting('price_reminder', value);

              if (!mounted) return;

              setState(() => priceReminder = value);
            },
          ),

          const Divider(height: 30),

          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('تحديث البيانات'),
            subtitle: const Text(
              'جلب آخر البيانات المتاحة من FPL',
            ),
            onTap: () {
              Navigator.pop(context);
              widget.onRefresh();
            },
          ),

          const ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('مصدر البيانات'),
            subtitle: Text(
              'واجهة بيانات Fantasy Premier League العامة',
            ),
          ),

          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('حول التطبيق'),
            subtitle: Text(
              'FPL Arabia • متابعة اللاعبين والإحصائيات والمباريات',
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'تنبيه: هذه النسخة لا تسجل الدخول إلى حساب FPL ولا تجري انتقالات نيابة عنك. '
            'الإشعارات الزمنية في الخلفية ومراقبة تغير الأسعار التلقائية تحتاج إلى تنفيذ إضافي.',
            style: TextStyle(
              color: AppColors.muted,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}