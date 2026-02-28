import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_contact_app/Style.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const MyApp());
}

class AppRefresh {
  static final Map<int, ValueNotifier<int>> _notifiers = {
    0: ValueNotifier(0),
    1: ValueNotifier(0),
    2: ValueNotifier(0),
  };

  static ValueNotifier<int> of(int tab) => _notifiers[tab]!;

  static void signal(int index) {
    if (_notifiers.containsKey(index)) {
      _notifiers[index]!.value++;
    }
  }
}

// ══════════════════════════════════════════════
//  MODELS
// ══════════════════════════════════════════════
class Contact {
  int? id;
  String firstName, lastName, company, mobile, mobile2, workEmail;
  String? imagePath;
  bool isFavourite;
  bool isBlocked;
  bool isEmergency;
  String notes;

  Contact({
    this.id,
    required this.firstName,
    this.lastName = '',
    this.company = '',
    required this.mobile,
    this.mobile2 = '',
    this.workEmail = '',
    this.imagePath,
    this.isFavourite = false,
    this.isBlocked = false,
    this.isEmergency = false,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'company': company,
    'mobile': mobile,
    'mobile2': mobile2,
    'workEmail': workEmail,
    'imagePath': imagePath,
    'isFavourite': isFavourite ? 1 : 0,
    'isBlocked': isBlocked ? 1 : 0,
    'isEmergency': isEmergency ? 1 : 0,
    'notes': notes,
  };

  factory Contact.fromMap(Map<String, dynamic> m) => Contact(
    id: m['id'],
    firstName: m['firstName'],
    lastName: m['lastName'] ?? '',
    company: m['company'] ?? '',
    mobile: m['mobile'],
    mobile2: m['mobile2'] ?? '',
    workEmail: m['workEmail'] ?? '',
    imagePath: m['imagePath'],
    isFavourite: (m['isFavourite'] ?? 0) == 1,
    isBlocked: (m['isBlocked'] ?? 0) == 1,
    isEmergency: (m['isEmergency'] ?? 0) == 1,
    notes: m['notes'] ?? '',
  );

  String get fullName => lastName.isEmpty ? firstName : '$firstName $lastName';
  String get initials {
    final a = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final b = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return a + b;
  }
}

enum CallType { outgoing, incoming, missed }

class RecentCall {
  int? id;
  int contactId;
  String contactName;
  String? contactImage;
  String phoneNumber;
  CallType callType;
  DateTime callTime;

  RecentCall({
    this.id,
    required this.contactId,
    required this.contactName,
    this.contactImage,
    required this.phoneNumber,
    required this.callType,
    required this.callTime,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'contactId': contactId,
    'contactName': contactName,
    'contactImage': contactImage,
    'phoneNumber': phoneNumber,
    'callType': callType.index,
    'callTime': callTime.millisecondsSinceEpoch,
  };

  factory RecentCall.fromMap(Map<String, dynamic> m) => RecentCall(
    id: m['id'],
    contactId: m['contactId'],
    contactName: m['contactName'],
    contactImage: m['contactImage'],
    phoneNumber: m['phoneNumber'],
    callType: CallType.values[m['callType']],
    callTime: DateTime.fromMillisecondsSinceEpoch(m['callTime']),
  );
}

class AppMessage {
  int? id;
  int contactId;
  String contactName;
  String? contactImage;
  String phoneNumber;
  String messageText;
  DateTime sentTime;
  bool isRead;

  AppMessage({
    this.id,
    required this.contactId,
    required this.contactName,
    this.contactImage,
    required this.phoneNumber,
    required this.messageText,
    required this.sentTime,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'contactId': contactId,
    'contactName': contactName,
    'contactImage': contactImage,
    'phoneNumber': phoneNumber,
    'messageText': messageText,
    'sentTime': sentTime.millisecondsSinceEpoch,
    'isRead': isRead ? 1 : 0,
  };

  factory AppMessage.fromMap(Map<String, dynamic> m) => AppMessage(
    id: m['id'],
    contactId: m['contactId'],
    contactName: m['contactName'],
    contactImage: m['contactImage'],
    phoneNumber: m['phoneNumber'],
    messageText: m['messageText'],
    sentTime: DateTime.fromMillisecondsSinceEpoch(m['sentTime']),
    isRead: (m['isRead'] ?? 0) == 1,
  );
}

// ══════════════════════════════════════════════
//  DATABASE
// ══════════════════════════════════════════════
class DB {
  static Database? _db;

  static Future<Database> get instance async => _db ??= await _open();

  static Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'contacts_ios_v2.db');
    return openDatabase(path, version: 2, onCreate: (db, _) async {
      await db.execute('''CREATE TABLE contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        firstName TEXT NOT NULL,
        lastName TEXT,
        company TEXT,
        mobile TEXT NOT NULL,
        mobile2 TEXT,
        workEmail TEXT,
        imagePath TEXT,
        isFavourite INTEGER DEFAULT 0,
        isBlocked INTEGER DEFAULT 0,
        isEmergency INTEGER DEFAULT 0,
        notes TEXT DEFAULT ""
      )''');
      await db.execute('''CREATE TABLE recent_calls(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contactId INTEGER,
        contactName TEXT,
        contactImage TEXT,
        phoneNumber TEXT,
        callType INTEGER,
        callTime INTEGER
      )''');
      await db.execute('''CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contactId INTEGER,
        contactName TEXT,
        contactImage TEXT,
        phoneNumber TEXT,
        messageText TEXT,
        sentTime INTEGER,
        isRead INTEGER DEFAULT 0
      )''');
      await db.execute('''CREATE TABLE blocked_numbers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contactId INTEGER,
        phoneNumber TEXT NOT NULL,
        blockedAt INTEGER
      )''');
      await db.execute('''CREATE TABLE emergency_contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contactId INTEGER NOT NULL,
        addedAt INTEGER
      )''');
    }, onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        try { await db.execute('ALTER TABLE contacts ADD COLUMN isBlocked INTEGER DEFAULT 0'); } catch (_) {}
        try { await db.execute('ALTER TABLE contacts ADD COLUMN isEmergency INTEGER DEFAULT 0'); } catch (_) {}
        try { await db.execute('ALTER TABLE contacts ADD COLUMN notes TEXT DEFAULT ""'); } catch (_) {}
        try { await db.execute('''CREATE TABLE IF NOT EXISTS messages(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contactId INTEGER,
          contactName TEXT,
          contactImage TEXT,
          phoneNumber TEXT,
          messageText TEXT,
          sentTime INTEGER,
          isRead INTEGER DEFAULT 0
        )'''); } catch (_) {}
        try { await db.execute('''CREATE TABLE IF NOT EXISTS blocked_numbers(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contactId INTEGER,
          phoneNumber TEXT NOT NULL,
          blockedAt INTEGER
        )'''); } catch (_) {}
        try { await db.execute('''CREATE TABLE IF NOT EXISTS emergency_contacts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contactId INTEGER NOT NULL,
          addedAt INTEGER
        )'''); } catch (_) {}
      }
    });
  }

  static Future<int> insertContact(Contact c) async =>
      (await instance).insert('contacts', c.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  static Future<List<Contact>> allContacts() async =>
      ((await instance).query('contacts', orderBy: 'firstName ASC'))
          .then((r) => r.map(Contact.fromMap).toList());

  static Future<List<Contact>> favourites() async =>
      ((await instance).query('contacts', where: 'isFavourite=1', orderBy: 'firstName ASC'))
          .then((r) => r.map(Contact.fromMap).toList());

  static Future<List<Contact>> emergencyContacts() async =>
      ((await instance).query('contacts', where: 'isEmergency=1', orderBy: 'firstName ASC'))
          .then((r) => r.map(Contact.fromMap).toList());

  static Future<List<Contact>> blockedContacts() async =>
      ((await instance).query('contacts', where: 'isBlocked=1', orderBy: 'firstName ASC'))
          .then((r) => r.map(Contact.fromMap).toList());

  static Future<Contact?> contactById(int id) async {
    final rows = await (await instance).query('contacts', where: 'id=?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Contact.fromMap(rows.first);
  }

  static Future<void> updateContact(Contact c) async =>
      (await instance).update('contacts', c.toMap(), where: 'id=?', whereArgs: [c.id]);

  static Future<void> toggleFav(Contact c) async {
    c.isFavourite = !c.isFavourite;
    await updateContact(c);
    AppRefresh.signal(0);
    AppRefresh.signal(2);
  }

  static Future<void> toggleBlocked(Contact c) async {
    c.isBlocked = !c.isBlocked;
    await updateContact(c);
    final db = await instance;
    if (c.isBlocked) {
      await db.insert('blocked_numbers', {
        'contactId': c.id,
        'phoneNumber': c.mobile,
        'blockedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await db.delete('blocked_numbers', where: 'contactId=?', whereArgs: [c.id]);
    }
    AppRefresh.signal(2);
  }

  static Future<void> toggleEmergency(Contact c) async {
    c.isEmergency = !c.isEmergency;
    await updateContact(c);
    final db = await instance;
    if (c.isEmergency) {
      await db.insert('emergency_contacts', {
        'contactId': c.id,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await db.delete('emergency_contacts', where: 'contactId=?', whereArgs: [c.id]);
    }
    AppRefresh.signal(2);
  }

  static Future<void> updateNotes(int contactId, String notes) async {
    final db = await instance;
    await db.update('contacts', {'notes': notes}, where: 'id=?', whereArgs: [contactId]);
  }

  static Future<void> deleteContact(int id) async {
    final db = await instance;
    await db.delete('contacts', where: 'id=?', whereArgs: [id]);
    await db.delete('blocked_numbers', where: 'contactId=?', whereArgs: [id]);
    await db.delete('emergency_contacts', where: 'contactId=?', whereArgs: [id]);
    AppRefresh.signal(0);
    AppRefresh.signal(2);
  }

  static Future<void> insertCall(RecentCall r) async {
    await (await instance).insert('recent_calls', r.toMap());
    AppRefresh.signal(1);
  }

  static Future<List<RecentCall>> recentCalls() async =>
      ((await instance).query('recent_calls', orderBy: 'callTime DESC', limit: 100))
          .then((r) => r.map(RecentCall.fromMap).toList());

  static Future<void> deleteCall(int id) async =>
      (await instance).delete('recent_calls', where: 'id=?', whereArgs: [id]);

  static Future<void> clearAllCalls() async =>
      (await instance).delete('recent_calls');

  static Future<int> insertMessage(AppMessage msg) async {
    final id = await (await instance).insert('messages', msg.toMap());
    return id;
  }

  static Future<List<AppMessage>> messagesForContact(int contactId) async =>
      ((await instance).query('messages',
          where: 'contactId=?', whereArgs: [contactId], orderBy: 'sentTime DESC'))
          .then((r) => r.map(AppMessage.fromMap).toList());

  static Future<List<AppMessage>> allMessages() async =>
      ((await instance).query('messages', orderBy: 'sentTime DESC'))
          .then((r) => r.map(AppMessage.fromMap).toList());

  static Future<void> deleteMessage(int id) async =>
      (await instance).delete('messages', where: 'id=?', whereArgs: [id]);

  static Future<List<Map<String, dynamic>>> blockedNumbers() async =>
      (await instance).query('blocked_numbers', orderBy: 'blockedAt DESC');

  static Future<List<Map<String, dynamic>>> emergencyEntries() async =>
      (await instance).query('emergency_contacts', orderBy: 'addedAt DESC');
}

// ══════════════════════════════════════════════
//  ANIMATION HELPERS
// ══════════════════════════════════════════════

/// Staggered fade+slide in for list items
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 60),
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

/// Pulsing scale animation for press feedback
class _PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const _PressScale({required this.child, this.onTap, this.scale = 0.95});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: widget.scale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => _ctrl.forward(),
    onTapUp: (_) {
      _ctrl.reverse();
      widget.onTap?.call();
    },
    onTapCancel: () => _ctrl.reverse(),
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}

/// Animated header title with shimmer reveal
class _AnimatedPageTitle extends StatefulWidget {
  final String text;
  final List<Color> gradColors;
  const _AnimatedPageTitle({required this.text, required this.gradColors});

  @override
  State<_AnimatedPageTitle> createState() => _AnimatedPageTitleState();
}

class _AnimatedPageTitleState extends State<_AnimatedPageTitle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(-0.1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(
      position: _slide,
      child: ShaderMask(
        shaderCallback: (r) => LinearGradient(
          colors: widget.gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(r),
        child: Text(widget.text, style: const TextStyle(
          fontSize: 34, fontWeight: FontWeight.w800,
          color: Colors.white, letterSpacing: -0.8,
        )),
      ),
    ),
  );
}

/// Animated FAB with bounce-in
class _AnimatedFAB extends StatefulWidget {
  final VoidCallback onTap;
  final LinearGradient grad;
  final Color shadowColor;
  final IconData icon;
  const _AnimatedFAB({
    required this.onTap,
    required this.grad,
    required this.shadowColor,
    required this.icon,
  });

  @override
  State<_AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<_AnimatedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: _PressScale(
      onTap: widget.onTap,
      scale: 0.92,
      child: Container(
        width: 56, height: 56,
        decoration: BoxDecoration(
          gradient: widget.grad,
          shape: BoxShape.circle,
          boxShadow: DS.shadow(widget.shadowColor, blur: 18, y: 6, opacity: 0.45),
        ),
        child: Icon(widget.icon, color: Colors.white, size: 28),
      ),
    ),
  );
}

/// Ripple/bounce animation for keypad buttons
class _KeypadButton extends StatefulWidget {
  final String key2;
  final String? sub;
  final VoidCallback onTap;
  const _KeypadButton({required this.key2, this.sub, required this.onTap});

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _press() async {
    HapticFeedback.lightImpact();
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _press,
    child: ScaleTransition(
      scale: _scale,
      child: Container(
        width: 76, height: 76,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.09),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(widget.key2, style: const TextStyle(
              fontSize: 28, color: Colors.white, fontWeight: FontWeight.w300)),
          if ((widget.sub ?? '').isNotEmpty)
            Text(widget.sub!, style: TextStyle(
                fontSize: 9, color: Colors.white.withOpacity(0.55),
                letterSpacing: 1.5, fontWeight: FontWeight.w500)),
        ]),
      ),
    ),
  );
}

/// Star pulse animation for favourite toggle
class _StarFavButton extends StatefulWidget {
  final bool isFavourite;
  final VoidCallback onTap;
  const _StarFavButton({required this.isFavourite, required this.onTap});

  @override
  State<_StarFavButton> createState() => _StarFavButtonState();
}

class _StarFavButtonState extends State<_StarFavButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _press() {
    _ctrl.forward(from: 0);
    HapticFeedback.mediumImpact();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _press,
    child: ScaleTransition(
      scale: _scale,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: Tween(begin: 0.85, end: 1.0)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          widget.isFavourite ? Icons.star_rounded : Icons.star_border_rounded,
          key: ValueKey(widget.isFavourite),
          color: widget.isFavourite ? const Color(0xFFFFB800) : DS.tertiary,
          size: 22,
        ),
      ),
    ),
  );
}

/// Animated avatar with scale+fade reveal
class _AnimatedAvatar extends StatefulWidget {
  final String name, initials;
  final String? imagePath;
  final double radius;
  final int delayMs;
  const _AnimatedAvatar({
    required this.name,
    required this.initials,
    this.imagePath,
    required this.radius,
    this.delayMs = 0,
  });

  @override
  State<_AnimatedAvatar> createState() => _AnimatedAvatarState();
}

class _AnimatedAvatarState extends State<_AnimatedAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: ScaleTransition(
      scale: _scale,
      child: GradAvatar(
        name: widget.name,
        initials: widget.initials,
        imagePath: widget.imagePath,
        radius: widget.radius,
      ),
    ),
  );
}

// ══════════════════════════════════════════════
//  APP ROOT
// ══════════════════════════════════════════════
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Phone',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: DS.groupedBg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    ),
    home: const Shell(),
  );
}

// ══════════════════════════════════════════════
//  SHELL — iOS-style bottom tab bar
// ══════════════════════════════════════════════
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with TickerProviderStateMixin {
  int _idx = 0;
  late AnimationController _tabAnimCtrl;
  late Animation<double> _tabFade;

  static const _pages = [
    FavouritesPage(),
    RecentsPage(),
    ContactsPage(),
    KeypadPage(),
    VoicemailPage(),
  ];

  @override
  void initState() {
    super.initState();
    _tabAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _tabFade = CurvedAnimation(parent: _tabAnimCtrl, curve: Curves.easeOut);
    _tabAnimCtrl.forward();
  }

  @override
  void dispose() {
    _tabAnimCtrl.dispose();
    super.dispose();
  }

  void _onTap(int i) async {
    if (i == _idx) {
      AppRefresh.signal(i);
      return;
    }
    await _tabAnimCtrl.reverse();
    setState(() => _idx = i);
    AppRefresh.signal(i);
    _tabAnimCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _tabFade,
        child: IndexedStack(index: _idx, children: _pages),
      ),
      bottomNavigationBar: _TabBar(selected: _idx, onTap: _onTap),
    );
  }
}

class _TabBar extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onTap;
  const _TabBar({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white.withOpacity(0.82), Colors.white.withOpacity(0.94)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
            border: Border(top: BorderSide(color: Colors.black.withOpacity(0.08), width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _TItem(icon: Icons.star_rounded, label: 'Favourites',
                      sel: selected == 0, onTap: () => onTap(0)),
                  _TItem(icon: Icons.access_time_filled_rounded, label: 'Recents',
                      sel: selected == 1, onTap: () => onTap(1)),
                  _TItem(icon: Icons.person_rounded, label: 'Contacts',
                      sel: selected == 2, onTap: () => onTap(2)),
                  _TItem(icon: Icons.dialpad_rounded, label: 'Keypad',
                      sel: selected == 3, onTap: () => onTap(3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TItem extends StatefulWidget {
  final IconData icon; final String label; final bool sel; final VoidCallback onTap;
  const _TItem({required this.icon, required this.label, required this.sel, required this.onTap});

  @override
  State<_TItem> createState() => _TItemState();
}

class _TItemState extends State<_TItem> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _bounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.92), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TItem old) {
    super.didUpdateWidget(old);
    if (!old.sel && widget.sel) {
      _ctrl.forward(from: 0);
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap, behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: widget.sel ? BoxDecoration(
          gradient: LinearGradient(
            colors: [DS.blue.withOpacity(0.13), DS.blue.withOpacity(0.07)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(DS.r20),
        ) : null,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: _bounce,
            child: Icon(widget.icon, color: widget.sel ? DS.blue : DS.tertiary, size: 24),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 280),
            style: TextStyle(
              fontSize: 9.5, letterSpacing: -0.2,
              color: widget.sel ? DS.blue : DS.tertiary,
              fontWeight: widget.sel ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(widget.label),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  FAVOURITES PAGE
// ══════════════════════════════════════════════
class FavouritesPage extends StatefulWidget {
  const FavouritesPage({super.key});
  @override State<FavouritesPage> createState() => _FavouritesPageState();
}

class _FavouritesPageState extends State<FavouritesPage>
    with SingleTickerProviderStateMixin {
  List<Contact> _favs = [];
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));
    _load();
    AppRefresh.of(0).addListener(_load);
  }

  @override
  void dispose() {
    AppRefresh.of(0).removeListener(_load);
    _headerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DB.favourites();
    if (mounted) {
      setState(() => _favs = list);
      _headerCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: DS.bgFavourites),
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FadeTransition(
          opacity: _headerFade,
          child: SlideTransition(
            position: _headerSlide,
            child: Padding(
              padding: const EdgeInsets.only(right: 15.0, top: 13.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: _PressScale(
                  onTap: () async {
                    await Nav.push(context, const FavouriteContactPicker());
                    AppRefresh.signal(0);
                    AppRefresh.signal(2);
                  },
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      gradient: DS.gBlue, shape: BoxShape.circle,
                      boxShadow: DS.shadow(DS.blue, blur: 10, y: 3, opacity: 0.35),
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          child: _AnimatedPageTitle(
            text: 'Favourites',
            gradColors: const [Color(0xFF0A84FF), Color(0xFF5E5CE6)],
          ),
        ),
        Expanded(
          child: _favs.isEmpty
              ? _EmptyView(icon: Icons.star_rounded, grad: DS.gBlue,
                  title: 'No Favourites',
                  sub: 'Star a contact\'s number from their detail page')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: _favs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final c = _favs[i];
                    return AnimatedListItem(
                      index: i,
                      delay: const Duration(milliseconds: 55),
                      child: Dismissible(
                        key: Key('fav_${c.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 22),
                          decoration: BoxDecoration(
                            gradient: DS.gRed,
                            borderRadius: BorderRadius.circular(DS.r16),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.delete_forever_outlined, color: Colors.white, size: 22),
                              SizedBox(height: 4),
                              Text('Remove', style: TextStyle(
                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: ctx,
                            builder: (dialogCtx) => _AnimatedDialog(
                              child: AlertDialog(
                                backgroundColor: const Color(0xFF1C1C1E),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.r16)),
                                title: const Text('Remove from Favourites',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                content: Text('Remove ${c.fullName} from Favourites?',
                                    style: const TextStyle(color: DS.secondary)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx, false),
                                    child: const Text('Cancel', style: TextStyle(color: DS.blue)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx, true),
                                    child: const Text('Remove',
                                        style: TextStyle(color: DS.red, fontWeight: FontWeight.w700)),
                                  ),
                                ],
                              ),
                            ),
                          ) ?? false;
                        },
                        onDismissed: (_) async {
                          await DB.toggleFav(c);
                          _load();
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('${c.firstName} removed from Favourites'),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 2),
                          ));
                        },
                        child: _ContactCard(
                          contact: c,
                          onTap: () async {
                            await Nav.push(ctx, ContactDetailPage(contact: c));
                            AppRefresh.signal(0);
                            AppRefresh.signal(2);
                          },
                          trailing: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              border: Border.all(color: DS.blue.withOpacity(0.5), width: 1.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.info_outline_rounded, color: DS.blue, size: 17),
                          ),
                          showPhone: true,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ])),
    );
  }
}

/// Animated dialog entry
class _AnimatedDialog extends StatefulWidget {
  final Widget child;
  const _AnimatedDialog({required this.child});

  @override
  State<_AnimatedDialog> createState() => _AnimatedDialogState();
}

class _AnimatedDialogState extends State<_AnimatedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: ScaleTransition(scale: _scale, child: widget.child),
  );
}

// ══════════════════════════════════════════════
//  RECENTS PAGE
// ══════════════════════════════════════════════
class RecentsPage extends StatefulWidget {
  const RecentsPage({super.key});
  @override State<RecentsPage> createState() => _RecentsPageState();
}

class _RecentsPageState extends State<RecentsPage>
    with SingleTickerProviderStateMixin {
  List<RecentCall> _all = [], _missed = [], _shown = [];
  bool _isMissed = false;
  final _q = TextEditingController();
  late AnimationController _segCtrl;
  late Animation<double> _segSlide;

  @override
  void initState() {
    super.initState();
    _segCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _segSlide = CurvedAnimation(parent: _segCtrl, curve: Curves.easeOut);
    _load();
    _q.addListener(_filter);
    AppRefresh.of(1).addListener(_load);
  }

  @override
  void dispose() {
    AppRefresh.of(1).removeListener(_load);
    _q.dispose();
    _segCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DB.recentCalls();
    if (!mounted) return;
    setState(() {
      _all    = list;
      _missed = list.where((c) => c.callType == CallType.missed).toList();
      _filter();
    });
  }

  void _filter() {
    final base = _isMissed ? _missed : _all;
    final q = _q.text.toLowerCase();
    setState(() => _shown = q.isEmpty
        ? base
        : base.where((c) => c.contactName.toLowerCase().contains(q)).toList());
  }

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inDays == 0) {
      final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m ${dt.hour >= 12 ? "PM" : "AM"}';
    }
    if (d.inDays == 1) return 'Yesterday';
    if (d.inDays < 7) return const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][dt.weekday - 1];
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: DS.bgRecents),
      child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(DS.r20),
                  boxShadow: DS.cardShadow,
                ),
                child: Row(
                  children: [
                    _SegBtn(
                      label: 'All',
                      sel: !_isMissed,
                      onTap: () {
                        setState(() { _isMissed = false; _filter(); });
                        HapticFeedback.selectionClick();
                      },
                    ),
                    _SegBtn(
                      label: 'Missed',
                      sel: _isMissed,
                      onTap: () {
                        setState(() { _isMissed = true; _filter(); });
                        HapticFeedback.selectionClick();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
          child: _AnimatedPageTitle(
            text: 'Recents',
            gradColors: const [Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _SearchBar(controller: _q),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                    .animate(anim),
                child: child,
              ),
            ),
            child: _shown.isEmpty
                ? _EmptyView(
                    key: const ValueKey('empty'),
                    icon: Icons.call_rounded, grad: DS.gIndigo,
                    title: _isMissed ? 'No Missed Calls' : 'No Recents',
                    sub: 'Your call history will appear here')
                : ListView.separated(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _shown.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final call = _shown[i];
                      final missed = call.callType == CallType.missed;
                      final out    = call.callType == CallType.outgoing;
                      return AnimatedListItem(
                        index: i,
                        delay: const Duration(milliseconds: 45),
                        child: Dismissible(
                          key: Key('rc_${call.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 22),
                            decoration: BoxDecoration(
                              gradient: DS.gRed,
                              borderRadius: BorderRadius.circular(DS.r16),
                            ),
                            child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                          ),
                          onDismissed: (_) async {
                            await DB.deleteCall(call.id!);
                            _load();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: DS.cardBg,
                              borderRadius: BorderRadius.circular(DS.r16),
                              boxShadow: DS.cardShadow,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: _CallAvatar(call: call),
                              title: Text(call.contactName, style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.2,
                                color: missed ? DS.red : DS.label,
                              )),
                              subtitle: Row(children: [
                                Icon(out ? Icons.north_east_rounded : Icons.south_west_rounded,
                                    size: 12,
                                    color: missed ? DS.red.withOpacity(0.8) : DS.secondary),
                                const SizedBox(width: 4),
                                Text('mobile', style: TextStyle(
                                  color: missed ? DS.red.withOpacity(0.8) : DS.secondary,
                                  fontSize: 13,
                                )),
                              ]),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                Text(_fmt(call.callTime), style: const TextStyle(
                                    color: DS.secondary, fontSize: 13)),
                                const SizedBox(width: 8),
                                _PressScale(
                                  child: Container(
                                    width: 30, height: 30,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: DS.blue.withOpacity(0.5), width: 1.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.info_outline_rounded,
                                        color: DS.blue, size: 16),
                                  ),
                                ),
                              ]),
                              onTap: () => _launchCall(call.phoneNumber),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ])),
    );
  }
}

// ══════════════════════════════════════════════
//  CONTACTS LIST PAGE
// ══════════════════════════════════════════════
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});
  @override State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> _all = [], _shown = [];
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _q.addListener(_filter);
    AppRefresh.of(2).addListener(_load);
  }

  @override
  void dispose() {
    AppRefresh.of(2).removeListener(_load);
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DB.allContacts();
    if (!mounted) return;
    setState(() { _all = list; _filter(); });
  }

  void _filter() {
    final q = _q.text.toLowerCase();
    setState(() => _shown = q.isEmpty
        ? _all
        : _all.where((c) => c.fullName.toLowerCase().contains(q) || c.mobile.contains(q)).toList());
  }

  Map<String, List<Contact>> get _grouped {
    final map = <String, List<Contact>>{};
    for (final c in _shown) {
      map.putIfAbsent(c.firstName[0].toUpperCase(), () => []).add(c);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;
    final keys = grouped.keys.toList()..sort();

    return Container(
      decoration: const BoxDecoration(gradient: DS.bgContacts),
      child: SafeArea(child: Stack(children: [
        Column(children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AnimatedPageTitle(
                text: 'Contacts',
                gradColors: const [Color(0xFF5E5CE6), Color(0xFFBF5AF2)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: _SearchBar(controller: _q),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: _shown.isEmpty
                  ? _EmptyView(
                      key: const ValueKey('empty'),
                      icon: Icons.person_search_rounded, grad: DS.gPurple,
                      title: 'No Contacts', sub: 'Use the + button to add contacts')
                  : ListView.builder(
                      key: const ValueKey('list'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: keys.length,
                      itemBuilder: (ctx, i) {
                        final letter = keys[i];
                        final contacts = grouped[letter]!;
                        return AnimatedListItem(
                          index: i,
                          delay: const Duration(milliseconds: 40),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 12, 4, 5),
                              child: ShaderMask(
                                shaderCallback: (r) => DS.gIndigo.createShader(r),
                                child: Text(letter, style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: Colors.white, letterSpacing: 0.2,
                                )),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: DS.cardBg,
                                borderRadius: BorderRadius.circular(DS.r16),
                                boxShadow: DS.cardShadow,
                              ),
                              child: Column(children: contacts.asMap().entries.map((e) {
                                final c = e.value;
                                final last = e.key == contacts.length - 1;
                                return Column(children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 3),
                                    onTap: () async {
                                      await Nav.push(ctx, ContactDetailPage(contact: c));
                                      AppRefresh.signal(0);
                                      AppRefresh.signal(2);
                                    },
                                    leading: GradAvatar(name: c.firstName, initials: c.initials,
                                        imagePath: c.imagePath, radius: 22),
                                    title: RichText(text: TextSpan(children: [
                                      TextSpan(text: '${c.firstName} ',
                                          style: const TextStyle(color: DS.label, fontSize: 16, letterSpacing: -0.2)),
                                      if (c.lastName.isNotEmpty)
                                        TextSpan(text: c.lastName, style: const TextStyle(
                                            color: DS.label, fontSize: 16,
                                            fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                                    ])),
                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                      if (c.isBlocked)
                                        const Icon(Icons.block_rounded, color: DS.red, size: 16),
                                      if (c.isEmergency)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 4),
                                          child: Icon(Icons.emergency_rounded, color: DS.red, size: 16),
                                        ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.chevron_right_rounded, color: DS.tertiary, size: 20),
                                    ]),
                                  ),
                                  if (!last) const Divider(height: 1, indent: 64, color: DS.separator),
                                ]);
                              }).toList()),
                            ),
                          ]),
                        );
                      },
                    ),
            ),
          ),
        ]),
        Positioned(
          bottom: 18, right: 18,
          child: _AnimatedFAB(
            onTap: () async {
              await Nav.push(context, const EditContactPage());
              AppRefresh.signal(0);
              AppRefresh.signal(2);
            },
            grad: DS.gIndigo,
            shadowColor: DS.indigo,
            icon: Icons.add_rounded,
          ),
        ),
      ])),
    );
  }
}

// ══════════════════════════════════════════════
//  KEYPAD PAGE
// ══════════════════════════════════════════════
class KeypadPage extends StatefulWidget {
  const KeypadPage({super.key});
  @override State<KeypadPage> createState() => _KeypadPageState();
}

class _KeypadPageState extends State<KeypadPage>
    with SingleTickerProviderStateMixin {
  String _num = '';
  late AnimationController _numCtrl;
  late Animation<double> _numScale;

  void _press(String v) {
    setState(() => _num += v);
    _numCtrl.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  void _del() {
    if (_num.isNotEmpty) {
      setState(() => _num = _num.substring(0, _num.length - 1));
      HapticFeedback.lightImpact();
    }
  }

  @override
  void initState() {
    super.initState();
    _numCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _numScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _numCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    super.dispose();
  }

  static const _rows = [['1','2','3'], ['4','5','6'], ['7','8','9'], ['*','0','#']];
  static const _sub  = {
    '2':'ABC','3':'DEF','4':'GHI','5':'JKL','6':'MNO',
    '7':'PQRS','8':'TUV','9':'WXYZ','0':'+','*':'','#':''
  };

  Future<void> _callAndLog() async {
    if (_num.isEmpty) return;
    await DB.insertCall(RecentCall(
      contactId: 0,
      contactName: _num,
      contactImage: null,
      phoneNumber: _num,
      callType: CallType.outgoing,
      callTime: DateTime.now(),
    ));
    await _launchCall(_num);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: DS.bgKeypad),
      child: SafeArea(child: Column(children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ScaleTransition(
            scale: _numScale,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Text(
                _num.isEmpty ? '' : _num,
                key: ValueKey(_num),
                style: const TextStyle(fontSize: 38, color: Colors.white,
                    fontWeight: FontWeight.w200, letterSpacing: 5),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        ..._rows.asMap().entries.map((rowEntry) => AnimatedListItem(
          index: rowEntry.key,
          delay: const Duration(milliseconds: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: rowEntry.value.map((k) => _KeypadButton(
                key2: k,
                sub: _sub[k],
                onTap: () => _press(k),
              )).toList(),
            ),
          ),
        )),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          const SizedBox(width: 76),
          _PressScale(
            onTap: _callAndLog,
            scale: 0.9,
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                gradient: DS.gGreen, shape: BoxShape.circle,
                boxShadow: DS.shadow(DS.green, blur: 20, y: 6, opacity: 0.5),
              ),
              child: const Icon(Icons.phone_rounded, color: Colors.white, size: 32),
            ),
          ),
          GestureDetector(
            onTap: _del,
            child: SizedBox(width: 76, height: 76,
                child: Icon(Icons.backspace_outlined,
                    color: Colors.white.withOpacity(0.5), size: 26)),
          ),
        ]),
      ])),
    );
  }
}

// ══════════════════════════════════════════════
//  VOICEMAIL PAGE
// ══════════════════════════════════════════════
class VoicemailPage extends StatelessWidget {
  const VoicemailPage({super.key});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF9F4FF), Color(0xFFEDE0FF)],
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
      ),
    ),
    child: SafeArea(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _PulsingIcon(
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(gradient: DS.gPurple, shape: BoxShape.circle,
              boxShadow: DS.shadow(DS.purple, blur: 22, opacity: 0.4)),
          child: const Icon(Icons.voicemail_rounded, color: Colors.white, size: 38),
        ),
      ),
      const SizedBox(height: 18),
      const Text('Voicemail', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
          color: DS.label, letterSpacing: -0.5)),
      const SizedBox(height: 6),
      const Text('No voicemail messages', style: TextStyle(fontSize: 15, color: DS.secondary)),
    ]))),
  );
}

/// Subtle continuous pulse for icons
class _PulsingIcon extends StatefulWidget {
  final Widget child;
  const _PulsingIcon({required this.child});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _scale = Tween(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}

// ══════════════════════════════════════════════
//  SEND MESSAGE BOTTOM SHEET
// ══════════════════════════════════════════════
class SendMessageSheet extends StatefulWidget {
  final Contact contact;
  const SendMessageSheet({super.key, required this.contact});
  @override State<SendMessageSheet> createState() => _SendMessageSheetState();
}

class _SendMessageSheetState extends State<SendMessageSheet>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  bool _sending = false;
  List<AppMessage> _history = [];
  late AnimationController _sheetCtrl;
  late Animation<Offset> _sheetSlide;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _sheetSlide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic));
    _sheetCtrl.forward();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (widget.contact.id != null) {
      final msgs = await DB.messagesForContact(widget.contact.id!);
      if (mounted) setState(() => _history = msgs);
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);

    final msg = AppMessage(
      contactId: widget.contact.id ?? 0,
      contactName: widget.contact.fullName,
      contactImage: widget.contact.imagePath,
      phoneNumber: widget.contact.mobile,
      messageText: text,
      sentTime: DateTime.now(),
    );
    await DB.insertMessage(msg);
    await _launchSms(widget.contact.mobile, body: text);

    _ctrl.clear();
    await _loadHistory();
    setState(() => _sending = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent & saved'), backgroundColor: Color(0xFF34C759)),
      );
    }
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? "PM" : "AM"}';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _sheetSlide,
      child: Container(
        decoration: const BoxDecoration(
          color: DS.groupedBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: DS.tertiary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(children: [
                GradAvatar(name: widget.contact.firstName, initials: widget.contact.initials,
                    imagePath: widget.contact.imagePath, radius: 22),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.contact.fullName, style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: DS.label)),
                  Text(widget.contact.mobile, style: const TextStyle(
                      fontSize: 13, color: DS.secondary)),
                ]),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: DS.secondary),
                ),
              ]),
            ),
            const Divider(height: 1, color: DS.separator),

            if (_history.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _history.length,
                  itemBuilder: (ctx, i) {
                    final msg = _history[i];
                    return AnimatedListItem(
                      index: i,
                      delay: const Duration(milliseconds: 50),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: DS.gBlue,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: DS.shadow(DS.blue, blur: 8, y: 2, opacity: 0.2),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(msg.messageText, style: const TextStyle(
                                color: Colors.white, fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(_fmtTime(msg.sentTime), style: TextStyle(
                                color: Colors.white.withOpacity(0.7), fontSize: 11)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: DS.cardBg,
                      borderRadius: BorderRadius.circular(DS.r24),
                      boxShadow: DS.cardShadow,
                    ),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      style: const TextStyle(fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: DS.tertiary),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _PressScale(
                  onTap: _sending ? null : _send,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      gradient: _sending ? DS.gGray : DS.gBlue,
                      shape: BoxShape.circle,
                      boxShadow: DS.shadow(DS.blue, blur: 10, y: 3, opacity: 0.3),
                    ),
                    child: _sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  NOTES EDIT BOTTOM SHEET
// ══════════════════════════════════════════════
class NotesSheet extends StatefulWidget {
  final Contact contact;
  const NotesSheet({super.key, required this.contact});
  @override State<NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<NotesSheet>
    with SingleTickerProviderStateMixin {
  late TextEditingController _ctrl;
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.contact.notes);
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    widget.contact.notes = _ctrl.text;
    await DB.updateNotes(widget.contact.id!, _ctrl.text);
    if (mounted) Navigator.pop(context, _ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: Container(
        decoration: const BoxDecoration(
          color: DS.groupedBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: DS.tertiary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(children: [
                const Text('Notes', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, color: DS.label)),
                const Spacer(),
                _PressScale(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: DS.gGreen,
                      borderRadius: BorderRadius.circular(DS.r20),
                      boxShadow: DS.shadow(DS.green, blur: 8, opacity: 0.3),
                    ),
                    child: const Text('Save', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
            const Divider(height: 1, color: DS.separator),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: DS.cardBg,
                  borderRadius: BorderRadius.circular(DS.r16),
                  boxShadow: DS.cardShadow,
                ),
                child: TextField(
                  controller: _ctrl,
                  maxLines: 6,
                  style: const TextStyle(fontSize: 15, color: DS.label),
                  decoration: const InputDecoration(
                    hintText: 'Add notes about this contact...',
                    hintStyle: TextStyle(color: DS.tertiary),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  CONTACT DETAIL PAGE
// ══════════════════════════════════════════════
class ContactDetailPage extends StatefulWidget {
  final Contact contact;
  const ContactDetailPage({super.key, required this.contact});
  @override State<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage>
    with TickerProviderStateMixin {
  late Contact _c;
  late AnimationController _heroCtrl;
  late Animation<double> _heroScale, _heroFade;
  late AnimationController _cardCtrl;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _c = widget.contact;

    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _heroScale = CurvedAnimation(parent: _heroCtrl, curve: Curves.elasticOut);
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);

    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutCubic));
    _cardFade = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOut);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _heroCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _cardCtrl.forward();
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  List<String> get _phones => [
    if (_c.mobile.isNotEmpty) _c.mobile,
    if (_c.mobile2.isNotEmpty) _c.mobile2,
  ];

  Future<void> _toggleFav() async {
    await DB.toggleFav(_c);
    setState(() {});
    _showToast(_c.isFavourite
        ? '${_c.firstName} added to Favourites ⭐'
        : '${_c.firstName} removed from Favourites');
  }

  Future<void> _toggleBlocked() async {
    if (!_c.isBlocked) {
      final ok = await _confirmDialog(
        title: 'Block Contact',
        message: 'Block ${_c.fullName}? They will not be able to call or message you.',
        confirmLabel: 'Block',
        destructive: true,
      );
      if (ok != true) return;
    }
    await DB.toggleBlocked(_c);
    setState(() {});
    _showToast(_c.isBlocked
        ? '${_c.firstName} has been blocked 🚫'
        : '${_c.firstName} has been unblocked');
  }

  Future<void> _toggleEmergency() async {
    await DB.toggleEmergency(_c);
    setState(() {});
    _showToast(_c.isEmergency
        ? '${_c.firstName} added to Emergency Contacts 🚨'
        : '${_c.firstName} removed from Emergency Contacts');
  }

  Future<void> _logCall(String ph) async {
    await DB.insertCall(RecentCall(
      contactId: _c.id ?? 0,
      contactName: _c.fullName,
      contactImage: _c.imagePath,
      phoneNumber: ph,
      callType: CallType.outgoing,
      callTime: DateTime.now(),
    ));
  }

  void _openMessageSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SendMessageSheet(contact: _c),
    );
  }

  Future<void> _openNotesSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotesSheet(contact: _c),
    );
    if (result != null) {
      setState(() => _c.notes = result);
    }
  }

  void _sheet(String title, List<_Item> items) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _ActionSheet(title: title, items: items),
    );
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => _AnimatedDialog(
        child: AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(DS.r16)),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Text(message, style: const TextStyle(color: DS.secondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF0A84FF))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel, style: TextStyle(
                color: destructive ? DS.red : DS.blue,
                fontWeight: FontWeight.w700,
              )),
            ),
          ],
        ),
      ),
    );
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final grad = DS.avatarGrad(_c.firstName);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: DS.bgDetail),
        child: SafeArea(child: ListView(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _PressScale(
                onTap: () => Navigator.pop(context),
                child: _GlassCircleBtn(icon: Icons.arrow_back_ios_new_rounded, dark: true),
              ),
              _PressScale(
                onTap: () async {
                  await Nav.push(context, EditContactPage(contact: _c));
                  final updated = await DB.allContacts();
                  final found = updated.where((c) => c.id == _c.id);
                  if (found.isNotEmpty && mounted) setState(() => _c = found.first);
                  AppRefresh.signal(0);
                  AppRefresh.signal(2);
                },
                child: _GlassPillBtn(label: 'Edit', dark: true),
              ),
            ]),
          ),

          // ── Avatar with animated entrance ──────
          const SizedBox(height: 6),
          Center(child: FadeTransition(
            opacity: _heroFade,
            child: ScaleTransition(
              scale: _heroScale,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: DS.shadow(grad.colors.first, blur: 30, y: 10, opacity: 0.5),
                    ),
                    child: GradAvatar(name: _c.firstName, initials: _c.initials,
                        imagePath: _c.imagePath, radius: 64),
                  ),
                  if (_c.isBlocked)
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        gradient: DS.gRed, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.block_rounded, color: Colors.white, size: 16),
                    ),
                  if (_c.isEmergency && !_c.isBlocked)
                    Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(
                        gradient: DS.gRed, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 16),
                    ),
                ],
              ),
            ),
          )),
          const SizedBox(height: 14),

          // ── Name with staggered reveal ─────────
          FadeTransition(
            opacity: _heroFade,
            child: Column(children: [
              Text(_c.fullName, style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.6,
              )),
              if (_c.company.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(_c.company, style: TextStyle(
                    fontSize: 14, color: Colors.white.withOpacity(0.6))),
              ],
              if (_c.isBlocked || _c.isEmergency) ...[
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (_c.isBlocked) _StatusBadge(label: 'Blocked', color: DS.red),
                  if (_c.isEmergency) ...[
                    if (_c.isBlocked) const SizedBox(width: 8),
                    _StatusBadge(label: 'Emergency', color: DS.orange),
                  ],
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 22),

          // ── Action buttons with staggered entrance ─
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FadeTransition(
              opacity: _cardFade,
              child: SlideTransition(
                position: _cardSlide,
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _DetailBtn(icon: Icons.message_rounded, label: 'message', grad: DS.gBlue,
                      onTap: () => _sheet('Messages', [
                        ..._phones.map((ph) => _Item('mobile', ph, onTap: () {
                          Navigator.pop(context);
                          _launchSms(ph);
                        })),
                        _Item('WhatsApp', null, arrow: true, onTap: () {
                          Navigator.pop(context);
                          final n = _phones.isNotEmpty ? _phones[0].replaceAll(RegExp(r'[^\d]'), '') : '';
                          _launch('https://wa.me/$n');
                        }),
                      ])),
                  _DetailBtn(icon: Icons.phone_rounded, label: 'call', grad: DS.gGreen,
                      onTap: () => _sheet('Call', _phones.map((ph) => _Item('mobile', ph, onTap: () {
                        Navigator.pop(context);
                        _logCall(ph);
                        _launchCall(ph);
                      })).toList())),
                  _DetailBtn(icon: Icons.videocam_rounded, label: 'video', grad: DS.gPurple,
                      onTap: () {
                        if (_phones.isNotEmpty) {
                          _logCall(_phones[0]);
                          _launchCall(_phones[0]);
                        }
                      }),
                  _DetailBtn(icon: Icons.mail_outline_rounded, label: 'mail', grad: DS.gOrange,
                      onTap: () {
                        if (_c.workEmail.isEmpty) {
                          _showToast('No email address');
                          return;
                        }
                        _sheet('Mail', [_Item('work', _c.workEmail, onTap: () {
                          Navigator.pop(context);
                          _launchMail(_c.workEmail);
                        })]);
                      }),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 26),

          // ── Detail cards with slide-up ─────────
          FadeTransition(
            opacity: _cardFade,
            child: SlideTransition(
              position: _cardSlide,
              child: Container(
                decoration: const BoxDecoration(
                  color: DS.groupedBg,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28), topRight: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                child: Column(children: [
                  _ICard(children: [
                    if (_c.mobile.isNotEmpty)
                      _IRow(
                        label: 'mobile',
                        value: _c.mobile,
                        trailing: _StarFavButton(
                          isFavourite: _c.isFavourite,
                          onTap: _toggleFav,
                        ),
                        onTap: () => _launchCall(_c.mobile),
                      ),
                    if (_c.mobile2.isNotEmpty)
                      _IRow(label: 'mobile', value: _c.mobile2,
                          onTap: () => _launchCall(_c.mobile2)),
                    if (_c.workEmail.isNotEmpty)
                      _IRow(label: 'work', value: _c.workEmail,
                          onTap: () => _launchMail(_c.workEmail)),

                    GestureDetector(
                      onTap: _openNotesSheet,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                        child: Row(children: [
                          Container(
                            width: 28, height: 28,
                            decoration: BoxDecoration(gradient: DS.gOrange,
                                borderRadius: BorderRadius.circular(7)),
                            child: const Icon(Icons.sticky_note_2_rounded,
                                color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Notes', style: TextStyle(fontSize: 16, color: DS.label2)),
                            if (_c.notes.isNotEmpty)
                              Text(_c.notes, style: const TextStyle(
                                  fontSize: 13, color: DS.secondary),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                            if (_c.notes.isEmpty)
                              const Text('Tap to add notes', style: TextStyle(
                                  fontSize: 13, color: DS.tertiary)),
                          ])),
                          const Icon(Icons.chevron_right_rounded, color: DS.tertiary, size: 18),
                        ]),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  _ICard(children: [
                    _ARow(
                      icon: Icons.message_rounded,
                      grad: DS.gBlue,
                      label: 'Send Message',
                      onTap: _openMessageSheet,
                    ),
                    _ARow(
                      icon: Icons.star_rounded,
                      grad: DS.gYellow,
                      label: _c.isFavourite ? 'Remove from Favourites' : 'Add to Favourites',
                      onTap: _toggleFav,
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 12),

                  _ICard(children: [
                    _ARow(
                      icon: Icons.emergency_rounded,
                      grad: DS.gRed,
                      label: _c.isEmergency
                          ? 'Remove from Emergency Contacts'
                          : 'Add to Emergency Contacts',
                      onTap: _toggleEmergency,
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 12),

                  _ICard(children: [
                    _ARow(
                      icon: _c.isBlocked ? Icons.check_circle_rounded : Icons.block_rounded,
                      grad: _c.isBlocked ? DS.gGreen : const LinearGradient(
                        colors: [Color(0xFFFF453A), Color(0xFFBF1029)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      label: _c.isBlocked ? 'Unblock Contact' : 'Block Contact',
                      textColor: _c.isBlocked ? DS.green : DS.red,
                      onTap: _toggleBlocked,
                      isLast: true,
                    ),
                  ]),

                  const SizedBox(height: 12),

                  _PressScale(
                    onTap: () async {
                      final ok = await _confirmDialog(
                        title: 'Delete Contact',
                        message: 'Delete ${_c.fullName}? This action cannot be undone.',
                        confirmLabel: 'Delete',
                        destructive: true,
                      );
                      if (ok == true && _c.id != null) {
                        await DB.deleteContact(_c.id!);
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    scale: 0.97,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: DS.gRed,
                        borderRadius: BorderRadius.circular(DS.r16),
                        boxShadow: DS.shadow(DS.red, blur: 14, y: 5, opacity: 0.35),
                      ),
                      child: const Center(child: Text('Delete Contact', style: TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ])),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(DS.r20),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 12, fontWeight: FontWeight.w700)),
  );
}

// ══════════════════════════════════════════════
//  EDIT / ADD CONTACT PAGE
// ══════════════════════════════════════════════
class EditContactPage extends StatefulWidget {
  final Contact? contact;
  const EditContactPage({super.key, this.contact});
  @override State<EditContactPage> createState() => _EditContactPageState();
}

class _EditContactPageState extends State<EditContactPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _first, _last, _company;
  final List<TextEditingController> _phones = [];
  final List<TextEditingController> _emails = [];
  String? _imgPath;
  final _picker = ImagePicker();
  bool get _editing => widget.contact != null;

  late AnimationController _avatarCtrl;
  late Animation<double> _avatarScale;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _first   = TextEditingController(text: c?.firstName ?? '');
    _last    = TextEditingController(text: c?.lastName ?? '');
    _company = TextEditingController(text: c?.company ?? '');
    _imgPath = c?.imagePath;
    if (c != null) {
      if (c.mobile.isNotEmpty)  _phones.add(TextEditingController(text: c.mobile));
      if (c.mobile2.isNotEmpty) _phones.add(TextEditingController(text: c.mobile2));
      if (c.workEmail.isNotEmpty) _emails.add(TextEditingController(text: c.workEmail));
    }
    if (_phones.isEmpty) _phones.add(TextEditingController());

    _avatarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _avatarScale = CurvedAnimation(parent: _avatarCtrl, curve: Curves.elasticOut);
    _avatarCtrl.forward();
  }

  @override
  void dispose() {
    for (final c in [_first, _last, _company, ..._phones, ..._emails]) c.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImg() async {
    final img = await _picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _imgPath = img.path);
      _avatarCtrl.forward(from: 0);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    if (_first.text.trim().isEmpty) { _snack('First name is required'); return; }
    if (_phones.isEmpty || _phones[0].text.trim().isEmpty) {
      _snack('Phone number is required'); return;
    }
    final c = Contact(
      id: widget.contact?.id,
      firstName: _first.text.trim(),
      lastName: _last.text.trim(),
      company: _company.text.trim(),
      mobile: _phones[0].text.trim(),
      mobile2: _phones.length > 1 ? _phones[1].text.trim() : '',
      workEmail: _emails.isNotEmpty ? _emails[0].text.trim() : '',
      imagePath: _imgPath,
      isFavourite: widget.contact?.isFavourite ?? false,
      isBlocked: widget.contact?.isBlocked ?? false,
      isEmergency: widget.contact?.isEmergency ?? false,
      notes: widget.contact?.notes ?? '',
    );
    _editing ? await DB.updateContact(c) : await DB.insertContact(c);
    AppRefresh.signal(0);
    AppRefresh.signal(2);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D0D1A), Color(0xFF181030), Color(0xFF1E1040)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Stack(alignment: Alignment.center, children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _PressScale(
                  onTap: () => Navigator.pop(context),
                  child: _GlassCircleBtn(icon: Icons.close_rounded, dark: true),
                ),
              ),
              Text(_editing ? 'Edit Contact' : 'New Contact',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              Align(
                alignment: Alignment.centerRight,
                child: _PressScale(
                  onTap: _save,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      gradient: DS.gGreen, shape: BoxShape.circle,
                      boxShadow: DS.shadow(DS.green, blur: 10, opacity: 0.4),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
          ),
          _PressScale(
            onTap: _pickImg,
            child: ScaleTransition(
              scale: _avatarScale,
              child: Column(children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _imgPath == null ? DS.avatarGrad(_first.text) : null,
                    boxShadow: DS.shadow(DS.indigo, blur: 20, y: 6, opacity: 0.4),
                  ),
                  child: _imgPath != null
                      ? CircleAvatar(radius: 56, backgroundImage: FileImage(File(_imgPath!)))
                      : const CircleAvatar(radius: 56, backgroundColor: Colors.transparent,
                          child: Icon(Icons.person_rounded, size: 68, color: Colors.white60)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(DS.r20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(_imgPath != null ? 'Change Photo' : 'Add Photo',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: Container(
            decoration: const BoxDecoration(
              color: DS.groupedBg,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(children: [
                _FormCard(children: [
                  _FField(ctrl: _first, hint: 'First name'),
                  _FField(ctrl: _last, hint: 'Last name'),
                  _FField(ctrl: _company, hint: 'Company', isLast: true),
                ]),
                const SizedBox(height: 12),
                _FormCard(children: [
                  ..._phones.asMap().entries.map((e) => _FPhoneRow(
                    ctrl: e.value, label: 'mobile', hint: 'Phone',
                    onRemove: () => setState(() { e.value.dispose(); _phones.removeAt(e.key); }),
                  )),
                  _FAddRow(label: 'add phone',
                      onTap: () => setState(() => _phones.add(TextEditingController()))),
                ]),
                const SizedBox(height: 12),
                _FormCard(children: [
                  ..._emails.asMap().entries.map((e) => _FPhoneRow(
                    ctrl: e.value, label: 'work', hint: 'Email',
                    onRemove: () => setState(() { e.value.dispose(); _emails.removeAt(e.key); }),
                  )),
                  _FAddRow(label: 'add email',
                      onTap: () => setState(() => _emails.add(TextEditingController()))),
                ]),
                const SizedBox(height: 12),
                _FormCard(children: [
                  _FAddRow(label: 'add pronouns', onTap: () {}),
                ]),
                const SizedBox(height: 32),
              ]),
            ),
          )),
        ])),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  REUSABLE COMPONENTS
// ══════════════════════════════════════════════

class GradAvatar extends StatelessWidget {
  final String name, initials;
  final String? imagePath;
  final double radius;
  const GradAvatar({super.key, required this.name, required this.initials,
      this.imagePath, required this.radius});

  @override
  Widget build(BuildContext context) {
    if (imagePath != null) {
      return CircleAvatar(radius: radius, backgroundImage: FileImage(File(imagePath!)));
    }
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(gradient: DS.avatarGrad(name), shape: BoxShape.circle),
      child: Center(child: Text(initials, style: TextStyle(
          color: Colors.white, fontSize: radius * 0.65, fontWeight: FontWeight.w700))),
    );
  }
}

class _CallAvatar extends StatelessWidget {
  final RecentCall call;
  const _CallAvatar({required this.call});

  @override
  Widget build(BuildContext context) {
    if (call.contactImage != null) {
      return CircleAvatar(radius: 24, backgroundImage: FileImage(File(call.contactImage!)));
    }
    final n = call.contactName;
    final init = n.isNotEmpty ? n[0].toUpperCase() : '?';
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(gradient: DS.avatarGrad(n), shape: BoxShape.circle),
      child: Center(child: Text(init, style: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showPhone;
  const _ContactCard({required this.contact, required this.onTap,
      this.trailing, this.showPhone = false});

  @override
  Widget build(BuildContext context) => _PressScale(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: DS.cardBg, borderRadius: BorderRadius.circular(DS.r16),
        boxShadow: DS.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        leading: GradAvatar(name: contact.firstName, initials: contact.initials,
            imagePath: contact.imagePath, radius: 24),
        title: Text(contact.fullName, style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: -0.2)),
        subtitle: showPhone
            ? Row(children: [
                const Icon(Icons.phone_rounded, size: 12, color: DS.secondary),
                const SizedBox(width: 3),
                const Text('mobile', style: TextStyle(color: DS.secondary, fontSize: 13)),
              ])
            : null,
        trailing: trailing,
      ),
    ),
  );
}

class _GlassBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GlassBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(DS.r20),
        boxShadow: DS.cardShadow,
      ),
      child: ShaderMask(
        shaderCallback: (r) => DS.gIndigo.createShader(r),
        child: Text(label, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
      ),
    ),
  );
}

class _GlassPillBtn extends StatelessWidget {
  final String label;
  final bool dark;
  const _GlassPillBtn({required this.label, this.dark = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    decoration: BoxDecoration(
      color: dark ? Colors.white.withOpacity(0.15) : Colors.white,
      borderRadius: BorderRadius.circular(DS.r20),
      border: dark ? Border.all(color: Colors.white.withOpacity(0.25)) : null,
      boxShadow: dark ? null : DS.cardShadow,
    ),
    child: Text(label, style: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600,
        color: dark ? Colors.white : DS.blue)),
  );
}

class _GlassCircleBtn extends StatelessWidget {
  final IconData icon;
  final bool dark;
  const _GlassCircleBtn({required this.icon, this.dark = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 36, height: 36,
    decoration: BoxDecoration(
      color: dark ? Colors.white.withOpacity(0.15) : Colors.white,
      shape: BoxShape.circle,
      border: dark ? Border.all(color: Colors.white.withOpacity(0.25)) : null,
      boxShadow: dark ? null : DS.cardShadow,
    ),
    child: Icon(icon, color: dark ? Colors.white : DS.label, size: 17),
  );
}

class _SegBtn extends StatelessWidget {
  final String label; final bool sel; final VoidCallback onTap;
  const _SegBtn({required this.label, required this.sel, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      decoration: BoxDecoration(
        gradient: sel ? DS.gIndigo : null,
        borderRadius: BorderRadius.circular(DS.r20),
        boxShadow: sel ? DS.shadow(DS.indigo, blur: 8, y: 2, opacity: 0.35) : null,
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 250),
        style: TextStyle(
          color: sel ? Colors.white : DS.secondary,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
        ),
        child: Text(label),
      ),
    ),
  );
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    decoration: BoxDecoration(
      color: DS.cardBg,
      borderRadius: BorderRadius.circular(DS.r12),
      boxShadow: DS.cardShadow,
    ),
    child: TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15, color: DS.label),
      decoration: InputDecoration(
        hintText: 'Search',
        hintStyle: const TextStyle(color: DS.tertiary),
        prefixIcon: ShaderMask(
          shaderCallback: (r) => DS.gIndigo.createShader(r),
          child: const Icon(Icons.search_rounded, color: Colors.white, size: 22),
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
      ),
    ),
  );
}

class _DetailBtn extends StatelessWidget {
  final IconData icon; final String label;
  final LinearGradient grad; final VoidCallback? onTap;
  const _DetailBtn({required this.icon, required this.label,
      required this.grad, this.onTap});

  @override
  Widget build(BuildContext context) => _PressScale(
    onTap: onTap,
    child: Column(children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          gradient: grad, shape: BoxShape.circle,
          boxShadow: DS.shadow(grad.colors.first, blur: 14, y: 4, opacity: 0.45),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(
          color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _ICard extends StatelessWidget {
  final List<Widget> children;
  const _ICard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: DS.cardBg,
      borderRadius: BorderRadius.circular(DS.r16),
      boxShadow: DS.cardShadow,
    ),
    child: Column(children: children),
  );
}

class _IRow extends StatelessWidget {
  final String label, value;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _IRow({required this.label, required this.value, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) => Column(children: [
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DS.r16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: DS.secondary, fontSize: 11.5,
                letterSpacing: 0.1, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: DS.blue, fontSize: 16,
                fontWeight: FontWeight.w500)),
          ])),
          if (trailing != null) trailing!,
        ]),
      ),
    ),
    const Divider(height: 1, indent: 16, color: DS.separator),
  ]);
}

class _ARow extends StatelessWidget {
  final IconData icon; final LinearGradient grad;
  final String label; final VoidCallback onTap;
  final bool isLast; final Color? textColor;
  const _ARow({required this.icon, required this.grad, required this.label,
      required this.onTap, this.isLast = false, this.textColor});

  @override
  Widget build(BuildContext context) => Column(children: [
    InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DS.r16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(gradient: grad, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 16, color: textColor ?? DS.label2)),
        ]),
      ),
    ),
    if (!isLast) const Divider(height: 1, indent: 58, color: DS.separator),
  ]);
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: DS.cardBg,
      borderRadius: BorderRadius.circular(DS.r16),
      boxShadow: DS.cardShadow,
    ),
    child: Column(children: children),
  );
}

class _FField extends StatelessWidget {
  final TextEditingController ctrl; final String hint; final bool isLast;
  const _FField({required this.ctrl, required this.hint, this.isLast = false});

  @override
  Widget build(BuildContext context) => Column(children: [
    TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 16, color: DS.label),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: DS.tertiary),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    if (!isLast) const Divider(height: 1, indent: 16, color: DS.separator),
  ]);
}

class _FPhoneRow extends StatelessWidget {
  final TextEditingController ctrl; final String label, hint;
  final VoidCallback onRemove;
  const _FPhoneRow({required this.ctrl, required this.label,
      required this.hint, required this.onRemove});

  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        _PressScale(
          onTap: onRemove,
          child: Container(
            width: 26, height: 26,
            decoration: BoxDecoration(gradient: DS.gRed, shape: BoxShape.circle),
            child: const Icon(Icons.remove_rounded, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (r) => DS.gIndigo.createShader(r),
          child: Text(label, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        const Icon(Icons.chevron_right_rounded, color: DS.blue, size: 16),
        const SizedBox(width: 4),
        Expanded(child: TextField(
          controller: ctrl,
          keyboardType: label == 'work' ? TextInputType.emailAddress : TextInputType.phone,
          style: const TextStyle(fontSize: 15, color: DS.label),
          decoration: InputDecoration(
            hintText: hint, hintStyle: const TextStyle(color: DS.tertiary),
            border: InputBorder.none, contentPadding: EdgeInsets.zero,
          ),
        )),
      ]),
    ),
    const Divider(height: 1, indent: 46, color: DS.separator),
  ]);
}

class _FAddRow extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _FAddRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => _PressScale(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(gradient: DS.gGreen, shape: BoxShape.circle),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(
            fontSize: 15, color: DS.label2, fontWeight: FontWeight.w500)),
      ]),
    ),
  );
}

class _Item {
  final String label; final String? sub; final bool arrow; final VoidCallback onTap;
  const _Item(this.label, this.sub, {this.arrow = false, required this.onTap});
}

class _ActionSheet extends StatefulWidget {
  final String title; final List<_Item> items;
  const _ActionSheet({required this.title, required this.items});

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(
      position: _slide,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(DS.r16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(DS.r16),
                  ),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(widget.title, style: const TextStyle(color: DS.secondary,
                          fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    ...widget.items.asMap().entries.map((e) {
                      final item = e.value;
                      return Column(children: [
                        const Divider(height: 1, color: Color(0xFF3A3A3C)),
                        InkWell(
                          onTap: item.onTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(item.label, style: const TextStyle(
                                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w500)),
                                if (item.sub != null) Text(item.sub!, style: const TextStyle(
                                    color: DS.secondary, fontSize: 14)),
                              ])),
                              if (item.arrow) const Icon(Icons.chevron_right_rounded, color: DS.secondary),
                            ]),
                          ),
                        ),
                      ]);
                    }),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(DS.r16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: _PressScale(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2E).withOpacity(0.92),
                      borderRadius: BorderRadius.circular(DS.r16),
                    ),
                    child: const Center(child: Text('Cancel', style: TextStyle(
                        color: Color(0xFF0A84FF), fontSize: 17, fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _EmptyView extends StatefulWidget {
  final IconData icon; final LinearGradient grad;
  final String title, sub;
  const _EmptyView({super.key, required this.icon, required this.grad,
      required this.title, required this.sub});

  @override
  State<_EmptyView> createState() => _EmptyViewState();
}

class _EmptyViewState extends State<_EmptyView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(child: FadeTransition(
    opacity: _fade,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center, children: [
      ScaleTransition(
        scale: _scale,
        child: Container(
          width: 80, height: 80,
          decoration: BoxDecoration(gradient: widget.grad, shape: BoxShape.circle,
              boxShadow: DS.shadow(widget.grad.colors.first, blur: 24, y: 6, opacity: 0.4)),
          child: Icon(widget.icon, size: 38, color: Colors.white),
        ),
      ),
      const SizedBox(height: 18),
      Text(widget.title, style: const TextStyle(fontSize: 20,
          fontWeight: FontWeight.w700, color: DS.label, letterSpacing: -0.3)),
      const SizedBox(height: 5),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(widget.sub, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: DS.secondary, height: 1.4)),
      ),
    ],
  )),
  );
}

// ══════════════════════════════════════════════
//  LAUNCH HELPERS
// ══════════════════════════════════════════════
Future<void> _launch(String url) async {
  final uri = Uri.parse(url);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('_launch error: $e — url: $url');
  }
}

Future<void> _launchCall(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Call error: $e');
  }
}

Future<void> _launchSms(String phone, {String body = ''}) async {
  try {
    Uri uri;
    if (body.isNotEmpty) {
      uri = Uri(scheme: 'smsto', path: phone, queryParameters: {'body': body});
    } else {
      uri = Uri(scheme: 'sms', path: phone);
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    try {
      await launchUrl(Uri.parse('sms:$phone'), mode: LaunchMode.externalApplication);
    } catch (e2) {
      debugPrint('SMS error: $e2');
    }
  }
}

Future<void> _launchMail(String email) async {
  final uri = Uri(scheme: 'mailto', path: email);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Mail error: $e');
  }
}

class Nav {
  static Future<T?> push<T>(BuildContext ctx, Widget page) =>
      Navigator.push<T>(ctx, PageRouteBuilder(
        pageBuilder: (_, a, __) => page,
        transitionsBuilder: (_, anim, sec, child) {
          final slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          final fade = CurvedAnimation(parent: anim, curve: const Interval(0.0, 0.5));
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 320),
      ));
}

// ══════════════════════════════════════════════
//  FAVOURITE CONTACT PICKER
// ══════════════════════════════════════════════
class FavouriteContactPicker extends StatefulWidget {
  const FavouriteContactPicker({super.key});
  @override
  State<FavouriteContactPicker> createState() => _FavouriteContactPickerState();
}

class _FavouriteContactPickerState extends State<FavouriteContactPicker>
    with SingleTickerProviderStateMixin {
  List<Contact> _all = [];
  List<Contact> _shown = [];
  final _q = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<String> _letters = [];
  late AnimationController _headerCtrl;
  late Animation<double> _headerFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _headerFade = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerCtrl.forward();
    _load();
    _q.addListener(_filter);
  }

  @override
  void dispose() {
    _q.dispose();
    _scrollCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await DB.allContacts();
    if (!mounted) return;
    setState(() { _all = list; _filter(); });
  }

  void _filter() {
    final q = _q.text.toLowerCase();
    final filtered = q.isEmpty
        ? List<Contact>.from(_all)
        : _all.where((c) =>
            c.fullName.toLowerCase().contains(q) ||
            c.mobile.contains(q)).toList();
    _buildLetters(filtered);
    setState(() => _shown = filtered);
  }

  void _buildLetters(List<Contact> contacts) {
    final seen = <String>{};
    final letters = <String>[];
    for (final c in contacts) {
      final l = c.firstName[0].toUpperCase();
      if (seen.add(l)) letters.add(l);
    }
    _letters = letters;
  }

  void _scrollToLetter(String letter) {
    int headerCount = 0;
    int rowCount = 0;
    String? cur;
    for (final c in _shown) {
      final l = c.firstName[0].toUpperCase();
      if (l == letter) break;
      if (l != cur) { headerCount++; cur = l; }
      rowCount++;
    }
    final offset = (headerCount * 36.0) + (rowCount * 58.0);
    _scrollCtrl.animateTo(
      offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
    );
    HapticFeedback.selectionClick();
  }

  void _showFavSheet(Contact c) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.25),
      isScrollControlled: true,
      builder: (_) => _FavActionSheet(
        contact: c,
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
          AppRefresh.signal(0);
          AppRefresh.signal(2);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: Stack(children: [
        Column(children: [
          FadeTransition(
            opacity: _headerFade,
            child: _PickerHeader(
              safeTop: safeTop,
              onBack: () => Navigator.pop(context),
              onClose: () => Navigator.pop(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: _PickerSearchBar(controller: _q),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: _shown.isEmpty
                  ? _PickerEmpty(key: const ValueKey('empty'), query: _q.text)
                  : _PickerContactList(
                      key: const ValueKey('list'),
                      contacts: _shown,
                      letters: _letters,
                      scrollCtrl: _scrollCtrl,
                      onTap: _showFavSheet,
                    ),
            ),
          ),
        ]),
        if (_q.text.isEmpty && _letters.isNotEmpty)
          Positioned(
            right: 2,
            top: 0,
            bottom: 0,
            child: _AlphaScrubber(
              letters: _letters,
              onSelect: _scrollToLetter,
            ),
          ),
      ]),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  final double safeTop;
  final VoidCallback onBack, onClose;
  const _PickerHeader({required this.safeTop, required this.onBack, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(height: safeTop + 10),
        Center(
          child: Text(
            'Choose a contact to add to Favourites',
            style: TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.45)),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(children: [
            _PressScale(
              onTap: onBack,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_left_rounded, color: Colors.black, size: 26),
              ),
            ),
            const Expanded(
              child: Center(
                child: Text('Contacts', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black, letterSpacing: -0.3,
                )),
              ),
            ),
            _PressScale(
              onTap: onClose,
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.black, size: 20),
              ),
            ),
          ]),
        ),
        Container(height: 0.5, color: Colors.black.withOpacity(0.15)),
      ]),
    );
  }
}

class _PickerSearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _PickerSearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 16, color: Colors.black),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(fontSize: 16, color: Colors.black.withOpacity(0.35)),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.black.withOpacity(0.4), size: 22),
          suffixIcon: Icon(Icons.mic_rounded, color: Colors.black.withOpacity(0.4), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _PickerContactList extends StatelessWidget {
  final List<Contact> contacts;
  final List<String> letters;
  final ScrollController scrollCtrl;
  final void Function(Contact) onTap;

  const _PickerContactList({
    super.key,
    required this.contacts,
    required this.letters,
    required this.scrollCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_PListItem>[];
    String? cur;
    for (int i = 0; i < contacts.length; i++) {
      final c = contacts[i];
      final letter = c.firstName[0].toUpperCase();
      if (letter != cur) {
        items.add(_PListItem.header(letter));
        cur = letter;
      }
      final nextLetter = i + 1 < contacts.length
          ? contacts[i + 1].firstName[0].toUpperCase()
          : null;
      items.add(_PListItem.contact(c, isLast: nextLetter != letter));
    }

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        if (item.isHeader) {
          return _PickerSectionHeader(letter: item.letter!);
        }
        return AnimatedListItem(
          index: i,
          delay: const Duration(milliseconds: 20),
          child: _PickerContactRow(
            contact: item.contact!,
            isLast: item.isLast,
            onTap: () => onTap(item.contact!),
          ),
        );
      },
    );
  }
}

class _PListItem {
  final bool isHeader;
  final String? letter;
  final Contact? contact;
  final bool isLast;
  const _PListItem._({required this.isHeader, this.letter, this.contact, this.isLast = false});
  factory _PListItem.header(String l) => _PListItem._(isHeader: true, letter: l);
  factory _PListItem.contact(Contact c, {bool isLast = false}) =>
      _PListItem._(isHeader: false, contact: c, isLast: isLast);
}

class _PickerSectionHeader extends StatelessWidget {
  final String letter;
  const _PickerSectionHeader({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF2F2F7),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(letter, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: Colors.black.withOpacity(0.45),
        )),
        const SizedBox(height: 6),
        Container(height: 0.5, color: Colors.black.withOpacity(0.15)),
      ]),
    );
  }
}

class _PickerContactRow extends StatelessWidget {
  final Contact contact;
  final bool isLast;
  final VoidCallback onTap;
  const _PickerContactRow({required this.contact, required this.isLast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.grey.withOpacity(0.15),
        highlightColor: Colors.grey.withOpacity(0.08),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              _PickerAvatar(contact: contact),
              const SizedBox(width: 14),
              Expanded(
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: contact.firstName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: contact.lastName.isEmpty ? FontWeight.w700 : FontWeight.w400,
                        color: Colors.black,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (contact.lastName.isNotEmpty)
                      TextSpan(
                        text: ' ${contact.lastName}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                          letterSpacing: -0.2,
                        ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          if (!isLast)
            Padding(
              padding: const EdgeInsets.only(left: 74),
              child: Container(height: 0.5, color: Colors.black.withOpacity(0.12)),
            ),
        ]),
      ),
    );
  }
}

class _PickerAvatar extends StatelessWidget {
  final Contact contact;
  const _PickerAvatar({required this.contact});

  @override
  Widget build(BuildContext context) {
    if (contact.imagePath != null) {
      return CircleAvatar(radius: 22, backgroundImage: FileImage(File(contact.imagePath!)));
    }
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        gradient: DS.avatarGrad(contact.firstName),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text(
        contact.initials,
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
      )),
    );
  }
}

class _AlphaScrubber extends StatefulWidget {
  final List<String> letters;
  final void Function(String) onSelect;
  const _AlphaScrubber({required this.letters, required this.onSelect});

  @override
  State<_AlphaScrubber> createState() => _AlphaScrubberState();
}

class _AlphaScrubberState extends State<_AlphaScrubber> {
  String? _active;

  void _handle(Offset local, double totalHeight) {
    if (widget.letters.isEmpty) return;
    final frac = (local.dy / totalHeight).clamp(0.0, 0.9999);
    final idx = (frac * widget.letters.length).floor();
    final letter = widget.letters[idx];
    if (letter != _active) {
      setState(() => _active = letter);
      widget.onSelect(letter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (d) => _handle(d.localPosition, constraints.maxHeight),
        onVerticalDragUpdate: (d) => _handle(d.localPosition, constraints.maxHeight),
        onVerticalDragEnd: (_) => setState(() => _active = null),
        onTapDown: (d) { _handle(d.localPosition, constraints.maxHeight); },
        onTapUp: (_) => setState(() => _active = null),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _active != null ? 24 : 20,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.letters.map((l) {
              final active = l == _active;
              return Expanded(
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    style: TextStyle(
                      fontSize: active ? 14 : 11,
                      fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                      color: const Color(0xFF007AFF),
                    ),
                    child: Text(l),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    });
  }
}

class _FavActionSheet extends StatefulWidget {
  final Contact contact;
  final VoidCallback onDone;
  const _FavActionSheet({required this.contact, required this.onDone});

  @override
  State<_FavActionSheet> createState() => _FavActionSheetState();
}

class _FavActionSheetState extends State<_FavActionSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addFav(BuildContext ctx) async {
    if (!widget.contact.isFavourite) {
      widget.contact.isFavourite = true;
      await DB.updateContact(widget.contact);
      AppRefresh.signal(0);
      AppRefresh.signal(2);
    }
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            10, 0, 10,
            MediaQuery.of(context).padding.bottom + 10,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text('Add to Favourites', style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black,
                  )),
                ),
                Container(height: 0.5, color: Colors.black.withOpacity(0.12)),
                _FavOptionRow(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Message',
                  onTap: () => _addFav(context),
                ),
                Container(height: 0.5, margin: const EdgeInsets.only(left: 56), color: Colors.black.withOpacity(0.1)),
                _FavOptionRow(
                  icon: Icons.phone_rounded,
                  label: 'Call',
                  onTap: () => _addFav(context),
                ),
                Container(height: 0.5, margin: const EdgeInsets.only(left: 56), color: Colors.black.withOpacity(0.1)),
                _FavOptionRow(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  isLast: true,
                  onTap: () => _addFav(context),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            _PressScale(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Center(child: Text('Cancel', style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black,
                ))),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FavOptionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;
  const _FavOptionRow({
    required this.icon, required this.label, required this.onTap, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(16))
          : BorderRadius.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : BorderRadius.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            Icon(icon, color: Colors.black.withOpacity(0.55), size: 24),
            const SizedBox(width: 18),
            Expanded(child: Text(label, style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w400, color: Colors.black,
            ))),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.black.withOpacity(0.35), size: 24),
          ]),
        ),
      ),
    );
  }
}

class _PickerEmpty extends StatelessWidget {
  final String query;
  const _PickerEmpty({super.key, required this.query});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.person_search_rounded, size: 56, color: Colors.black.withOpacity(0.2)),
      const SizedBox(height: 12),
      Text(
        query.isEmpty ? 'No Contacts' : 'No results for "$query"',
        style: TextStyle(fontSize: 16, color: Colors.black.withOpacity(0.4), fontWeight: FontWeight.w500),
      ),
    ],
  ));
}