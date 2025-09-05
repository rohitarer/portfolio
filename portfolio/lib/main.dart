// lib/main.dart
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, PointerDeviceKind;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

void main() => runApp(const PortfolioApp());

Future<void> _open(String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(
    uri,
    mode: LaunchMode.externalApplication, // opens outside the app (web/mobile)
  );
  if (!ok) {
    // fallback: copy if the device can't launch
    await Clipboard.setData(ClipboardData(text: url));
  }
}

/// ---------- 3D PLATFORM BACKGROUND (full-screen, colorful) ----------
class _Platform3DBackground extends StatefulWidget {
  final AnimationController controller; // reuse your _blobCtrl
  const _Platform3DBackground({required this.controller});

  @override
  State<_Platform3DBackground> createState() => _Platform3DBackgroundState();
}

class _Platform3DBackgroundState extends State<_Platform3DBackground> {
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _anim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: widget.controller, curve: Curves.linear));
  }

  @override
  Widget build(BuildContext context) {
    final gridTint = Theme.of(context).colorScheme.primary;
    final fadeColor = Theme.of(context).colorScheme.surface;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _anim,
        builder:
            (_, __) => CustomPaint(
              painter: _Platform3DPainter(
                t: _anim.value,
                gridTint: gridTint,
                fadeColor: fadeColor,
                isDark: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
      ),
    );
  }
}

class _Platform3DPainter extends CustomPainter {
  final double t; // 0..1 looping
  final Color gridTint; // seed color from theme
  final Color fadeColor; // kept for API parity
  final bool isDark;

  _Platform3DPainter({
    required this.t,
    required this.gridTint,
    required this.fadeColor,
    required this.isDark,
  });

  // Perspective projection
  Offset _project(
    Size size,
    double x,
    double y,
    double z, {
    double fov = 1.15,
    double camY = 2.0,
    double camZ = -3.8,
  }) {
    final wx = x;
    final wy = y - camY;
    final wz = z - camZ;

    final eps = 1e-6;
    final invZ = 1 / (wz.abs() < eps ? eps : wz);
    final focal = (size.shortestSide) / (2 * math.tan(fov / 2));

    final sx = size.width * 0.5 + wx * focal * invZ;
    final sy = size.height * 0.62 + wy * focal * invZ; // horizon ~38% from top
    return Offset(sx, sy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final seedHue = HSLColor.fromColor(gridTint).hue;
    final baseHue =
        (0.7 * 210.0 + 0.3 * seedHue) % 360.0; // anchor around blue/teal

    Color peacock(
      double hue, {
      double s = 0.90,
      double lDark = 0.58,
      double lLight = 0.46, // slightly darker than 0.5 so it "reads" on white
      double a = 1,
    }) {
      final l = isDark ? lDark : lLight;
      return HSLColor.fromAHSL(a, hue % 360.0, s, l).toColor();
    }

    // ---------- BACKDROP ----------
    if (isDark) {
      // keep the rich neon dark background
      final sky =
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0B0F17), Color(0xFF0E1624), Color(0xFF101826)],
              stops: [0.0, 0.45, 1.0],
            ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, sky);
    } else {
      // Bright peacock-ish light background (white → skyblue → mint aqua)
      final sky =
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF), // pure white at top
                Color(0xFFEAF7FF), // light sky-blue
                Color(0xFFE7FFF6), // light mint/greenish
              ],
              stops: [0.0, 0.38, 1.0],
            ).createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, sky);
    }

    // ---------- PORTAL / SUN ----------
    final sunCenter = Offset(size.width * 0.5, size.height * 0.28);
    final sunR = size.shortestSide * (isDark ? 0.18 : 0.22);
    final sunHue = baseHue + 22.0 * math.sin(t * 2 * math.pi * 0.4);
    final sunCore = peacock(
      sunHue,
      s: isDark ? 0.95 : 0.80,
      lDark: 0.68,
      lLight: 0.58,
      a:
          isDark
              ? 0.80
              : 0.42, // lower alpha on light to avoid washing out white
    );
    final sunPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              sunCore,
              sunCore.withOpacity(isDark ? 0.40 : 0.22),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: sunCenter, radius: sunR));
    canvas.drawCircle(sunCenter, sunR, sunPaint);

    // ---------- SCANNING SWEEP ----------
    final sweepY = size.height * (0.46 + 0.12 * math.sin(t * 2 * math.pi));
    final sweepColor = peacock(
      baseHue + 8,
      s: 0.9,
      lDark: 0.62,
      lLight: 0.48,
      a: isDark ? 0.28 : 0.22,
    );
    final sweepPaint =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, sweepColor, Colors.transparent],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromLTWH(0, sweepY - 90, size.width, 180))
          ..blendMode =
              isDark
                  ? BlendMode.plus
                  : BlendMode.srcOver; // additive only in dark
    canvas.drawRect(Rect.fromLTWH(0, sweepY - 90, size.width, 180), sweepPaint);

    // ---------- GRID ----------
    const gridHalfWidth = 10;
    const gridDepth = 30;
    const step = 1.0;
    const waveAmp = 0.28;
    const waveFreqX = 0.62;
    const waveFreqZ = 0.20;
    const scrollSpeed = 12.0;

    final zScroll = t * scrollSpeed;

    // On white, use thicker strokes & no blur for crispness
    final strokeBoost = isDark ? 1.0 : 1.5;
    final blurRadius = isDark ? 2.0 : 0.0;

    final linePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true
          ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver
          ..maskFilter =
              (blurRadius > 0)
                  ? MaskFilter.blur(BlurStyle.outer, blurRadius)
                  : null;

    // Neon color per depth/column (peacock range) + visibility boost on light
    Color depthColor(double z, {double hueBias = 0.0}) {
      final dist = (z / (gridDepth + 4)).clamp(0.0, 1.0); // 0 near .. 1 far
      final center = baseHue + 10; // keep peacock range
      final span = 60.0;
      final wobble = 8.0 * math.sin(t * 2 * math.pi * 0.5);
      final hue =
          center + (hueBias * 0.15 + (1 - dist) * (span * 0.4) + wobble);

      if (isDark) {
        // Dark mode (unchanged neon feel)
        final alpha = 0.20 + 0.75 * (1 - dist);
        return HSLColor.fromAHSL(alpha, hue % 360, 0.90, 0.60).toColor();
      } else {
        // // LIGHT MODE: make strokes lighter/pastel & a bit more transparent
        // final alpha = 0.12 + 0.38 * (1 - dist); // lower opacity on white
        // final sat = 0.50; // less saturated (pastel)
        // final light = 0.72; // brighter so it reads on white
        // return HSLColor.fromAHSL(alpha, hue % 360, sat, light).toColor();
        // LIGHT MODE: bluish–greenish (peacock) strokes on white
        final dist = (z / (gridDepth + 4)).clamp(0.0, 1.0);
        final alpha =
            0.14 + 0.40 * (1 - dist); // a bit stronger so it reads on white
        final centerHue = 188.0; // teal/peacock center (~blue-green)
        final span = 24.0; // small range around teal
        final wobble = 6.0 * math.sin(t * 2 * math.pi * 0.6); // subtle shimmer
        final hue =
            (centerHue +
                hueBias * 0.10 + // slight rainbow across X
                (1 - dist) * (span * 0.5) + // nearer = a touch more cyan
                wobble) %
            360.0;

        final sat = 0.58; // moderately vivid (pastel-ish)
        final light = 0.70; // bright enough on white
        return HSLColor.fromAHSL(alpha, hue, sat, light).toColor();
      }
    }

    // Horizontal lines
    for (int rz = 0; rz < gridDepth; rz++) {
      final z = rz * step + zScroll % step;
      final path = Path();
      bool first = true;

      for (int rx = -gridHalfWidth; rx <= gridHalfWidth; rx++) {
        final x = rx * step.toDouble();
        final y =
            math.sin((x * waveFreqX) + (z * waveFreqZ) + t * 6.0) * waveAmp;
        final p = _project(size, x, y, z);
        if (first) {
          path.moveTo(p.dx, p.dy);
          first = false;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }

      final near = 1.0 - (rz / gridDepth);
      linePaint
        ..color = depthColor(z)
        ..strokeWidth = (1.0 + 1.1 * near) * strokeBoost;
      canvas.drawPath(path, linePaint);
    }

    // Vertical lines (rainbow across X within peacock range)
    for (int rx = -gridHalfWidth; rx <= gridHalfWidth; rx++) {
      final x = rx * step.toDouble();
      final path = Path();
      bool first = true;

      for (int rz = 0; rz < gridDepth; rz++) {
        final z = rz * step + zScroll % step;
        final y =
            math.sin((x * waveFreqX) + (z * waveFreqZ) + t * 6.0) * waveAmp;
        final p = _project(size, x, y, z);
        if (first) {
          path.moveTo(p.dx, p.dy);
          first = false;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }

      final bias = (rx + gridHalfWidth) * 5.0;
      linePaint
        ..color = depthColor(0.0, hueBias: bias)
        ..strokeWidth = 1.4 * strokeBoost;
      canvas.drawPath(path, linePaint);
    }

    // Vignette: keep extremely subtle in light mode
    final vignette =
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, 0.35),
            radius: 1.2,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(isDark ? 0.10 : 0.05),
            ],
            stops: const [0.6, 1.0],
          ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _Platform3DPainter old) =>
      old.t != t ||
      old.gridTint != gridTint ||
      old.fadeColor != fadeColor ||
      old.isDark != isDark;
}

class _ImageActionButton extends StatelessWidget {
  final String asset;
  final VoidCallback onTap;
  final double size;
  final String? tooltip;
  final String? semanticsLabel;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final BoxFit fit;

  const _ImageActionButton({
    required this.asset,
    required this.onTap,
    this.size = 44,
    this.tooltip,
    this.semanticsLabel,
    this.padding = EdgeInsets.zero, // <-- default: no inner padding
    this.borderRadius = 12,
    this.fit =
        BoxFit.contain, // <-- use BoxFit.cover if you prefer edge-to-edge crop
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: padding,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.asset(
                asset,
                fit: fit, // <-- fill behavior
                errorBuilder: (_, __, ___) => const Icon(Icons.image),
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: tooltip == null ? btn : Tooltip(message: tooltip!, child: btn),
    );
  }
}

/// ---------- THE APP ----------
class PortfolioApp extends StatefulWidget {
  const PortfolioApp({super.key});
  @override
  State<PortfolioApp> createState() => _PortfolioAppState();
}

class _PortfolioAppState extends State<PortfolioApp> {
  ThemeMode mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    final light = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C7DFF)),
      scaffoldBackgroundColor: const Color(0xFFF6F7FB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
    );

    final dark = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6C7DFF),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0E1116),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rohit Arer · Portfolio',
      theme: light,
      darkTheme: dark,
      themeMode: mode,
      home: HomePage(
        onToggleTheme: () {
          setState(() {
            mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
          });
        },
        isDark: mode == ThemeMode.dark,
      ),
    );
  }
}

/// ---------- BREAKPOINTS ----------
class _Bp {
  static const mobile = 700.0;
  static const tablet = 1100.0;
}

/// ---------- HOME ----------
class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;
  const HomePage({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final aboutKey = GlobalKey();
  final expKey = GlobalKey();
  final projectsKey = GlobalKey();
  final contactKey = GlobalKey();
  final _scrollCtrl = ScrollController();

  late final AnimationController _blobCtrl;

  @override
  void initState() {
    super.initState();
    _blobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _blobCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _jumpTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.12,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < _Bp.mobile;

    return Scaffold(
      extendBodyBehindAppBar: false,
      drawer:
          isMobile
              ? _AppDrawer(
                onSelect: _jumpTo,
                keys: _NavKeys(aboutKey, expKey, projectsKey, contactKey),
              )
              : null,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: _GlassAppBar(
          title: 'Rohit Arer',
          isMobile: isMobile,
          onToggleTheme: widget.onToggleTheme,
          isDark: widget.isDark,
          actions:
              isMobile
                  ? const []
                  : [
                    _NavBtn(text: 'About', onTap: () => _jumpTo(aboutKey)),
                    _NavBtn(text: 'Experience', onTap: () => _jumpTo(expKey)),
                    _NavBtn(
                      text: 'Projects',
                      onTap: () => _jumpTo(projectsKey),
                    ),
                    _NavBtn(text: 'Contact', onTap: () => _jumpTo(contactKey)),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed:
                          () => _open(
                            'https://drive.google.com/your-resume-link',
                          ),
                      icon: Image.asset(
                        'assets/resume2.png', // <- your resume icon image
                        width: 18,
                        height: 18,
                        color:
                            Theme.of(context)
                                .colorScheme
                                .onPrimary, // remove if icon is multicolor
                      ),
                      label: const Text('Resume'),
                    ),

                    const SizedBox(width: 12),
                  ],
        ),
      ),

      // 🔧 Background + content layered correctly
      body: PrimaryScrollController(
        controller: _scrollCtrl, // <- your existing controller
        child: Stack(
          children: [
            // Full-screen 3D background
            Positioned.fill(
              child: IgnorePointer(
                child: _Platform3DBackground(controller: _blobCtrl),
              ),
            ),

            // Foreground scrollable content + scrollbar
            Scrollbar(
              thumbVisibility: true, // optional
              child: SingleChildScrollView(
                primary: true, // <- attach to PrimaryScrollController
                child: Column(
                  children: [
                    _Hero(
                      controller: _blobCtrl,
                      onHire: () => _open('mailto:rohitarer00@gmail.com'),
                      onGitHub: () => _open('https://github.com/rohitarer'),
                      onLinkedIn:
                          () => _open(
                            'https://www.linkedin.com/in/rohit-arer-a96294214/',
                          ),
                    ),
                    _SectionPad(key: aboutKey, child: const _About()),
                    _SectionPad(key: expKey, child: const _Experience()),
                    _SectionPad(key: projectsKey, child: const _Projects()),
                    _SectionPad(key: contactKey, child: const _Contact()),
                    const _Footer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- GLASS APP BAR ----------
class _GlassAppBar extends StatelessWidget {
  final String title;
  final bool isMobile;
  final List<Widget> actions;
  final VoidCallback onToggleTheme;
  final bool isDark;

  const _GlassAppBar({
    required this.title,
    required this.isMobile,
    required this.actions,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bar = AppBar(
      backgroundColor: Colors.transparent,
      title: Text(title),
      leading:
          isMobile
              ? Builder(
                builder:
                    (ctx) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      onPressed: () => Scaffold.of(ctx).openDrawer(),
                    ),
              )
              : null,
      actions: [
        ...actions,
        // NEW: NexaBill promo action
        _NexaBillAction(isCompact: isMobile),

        // Existing theme toggle
        IconButton(
          tooltip: 'Toggle theme',
          onPressed: onToggleTheme,
          icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
        ),
      ],
    );

    // Glassy wrapper (unchanged)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: bar,
          ),
        ),
      ),
    );
  }
}

class _NexaBillAction extends StatelessWidget {
  final bool isCompact; // true on mobile => icon-only
  const _NexaBillAction({required this.isCompact});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    if (isCompact) {
      // Mobile: small image button (keeps app bar tight)
      return Tooltip(
        message: 'Visit NexaBill',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _ImageActionButton(
            asset: 'assets/nexabill.jpeg',
            tooltip: 'Visit NexaBill',
            semanticsLabel: 'Visit NexaBill',
            onTap: () => _open('https://www.nexabill.in'),
            size: 40,
            padding: EdgeInsets.zero, // <-- no inner spacing
            fit:
                BoxFit
                    .cover, // <-- fills the box; switch to contain if you never want cropping
            borderRadius: 8, // optional
          ),
        ),
      );
    }

    // Desktop/Tablet: pill with logo + text
    return Tooltip(
      message: 'Visit NexaBill',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: TextButton.icon(
          onPressed: () => _open('https://www.nexabill.in'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: c.surfaceVariant.withOpacity(0.6),
            foregroundColor: c.primary,
          ),
          icon: SizedBox(
            width: 18,
            height: 18,
            child: Image.asset(
              'assets/nexabill.jpeg',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.link),
            ),
          ),
          label: const Text('Visit NexaBill'),
        ),
      ),
    );
  }
}

/// ---------- NAV ----------
class _NavBtn extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _NavBtn({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onTap, child: Text(text));
  }
}

class _NavKeys {
  final GlobalKey about, exp, proj, contact;
  _NavKeys(this.about, this.exp, this.proj, this.contact);
}

class _AppDrawer extends StatelessWidget {
  final Function(GlobalKey) onSelect;
  final _NavKeys keys;
  const _AppDrawer({required this.onSelect, required this.keys});
  @override
  Widget build(BuildContext context) {
    Widget item(String t, GlobalKey k, IconData i) => ListTile(
      leading: Icon(i),
      title: Text(t),
      onTap: () {
        Navigator.pop(context);
        onSelect(k);
      },
    );
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const ListTile(
              title: Text(
                'Navigate',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const Divider(height: 1),
            item('About', keys.about, Icons.person_outline),
            item('Experience', keys.exp, Icons.timeline),
            item('Projects', keys.proj, Icons.apps_outlined),
            item('Contact', keys.contact, Icons.mail_outline),
            const Spacer(),
            ListTile(
              leading: Image.asset(
                'assets/resume2.png', // <- your resume icon
                width: 24,
                height: 24,
                // color: Theme.of(context).colorScheme.onSurface, // uncomment to tint monochrome assets
              ),
              title: const Text('Resume'),
              onTap: () {
                Navigator.pop(context); // close the drawer
                _open('https://drive.google.com/your-resume-link');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- HERO ----------
class _Hero extends StatelessWidget {
  final AnimationController controller;
  final VoidCallback onHire, onGitHub, onLinkedIn;
  const _Hero({
    required this.controller,
    required this.onHire,
    required this.onGitHub,
    required this.onLinkedIn,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < _Bp.mobile;

    return SizedBox(
      height: isMobile ? 640 : 720,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle gradient background
          // Positioned.fill(
          //   child: DecoratedBox(
          //     decoration: BoxDecoration(
          //       gradient: LinearGradient(
          //         begin: Alignment.topLeft,
          //         end: Alignment.bottomRight,
          //         colors: [
          //           Theme.of(context).colorScheme.primary.withOpacity(0.06),
          //           Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          //           Colors.transparent,
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
          // // Animated blobs
          // _AnimatedBlob(
          //   controller: controller,
          //   size: isMobile ? 220 : 300,
          //   color: Theme.of(context).colorScheme.primary,
          //   dx: 0.15,
          //   dy: -0.12,
          // ),
          // _AnimatedBlob(
          //   controller: controller,
          //   size: isMobile ? 260 : 360,
          //   color: Theme.of(context).colorScheme.tertiary,
          //   dx: -0.25,
          //   dy: 0.18,
          // ),
          // _AnimatedBlob(
          //   controller: controller,
          //   size: isMobile ? 180 : 240,
          //   color: Theme.of(context).colorScheme.secondary,
          //   dx: 0.28,
          //   dy: 0.22,
          // ),
          // ✅ Add: true 3D platform background
          // Positioned.fill(child: _Platform3DBackground(controller: controller)),

          // Content
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 28,
                runSpacing: 28,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.center,
                children: [
                  // Profile card with 3D tilt
                  _Tilt3D(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: isMobile ? w * 0.9 : 420,
                        height: isMobile ? 260 : 460,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF161A2B), Color(0xFF28324D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),

                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Opacity(
                              opacity: 0.7,
                              child: Image.asset(
                                'assets/rohit.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'Rohit Arer',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Headline & CTAs
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isMobile ? 680 : 720),
                    child: Column(
                      crossAxisAlignment:
                          isMobile
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hi, I'm Rohit",
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'AI · ML · Flutter Developer',
                          textAlign:
                              isMobile ? TextAlign.center : TextAlign.start,
                          style: Theme.of(
                            context,
                          ).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.1,
                          ),
                        ),

                        const SizedBox(height: 12),
                        Text(
                          "I design & build intelligent apps that blend Flutter, Firebase, and AI.\n"
                          "From retail IoT to anonymous file-share, I ship fast, robust products.",
                          textAlign:
                              isMobile ? TextAlign.center : TextAlign.start,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(
                            height: 1.55,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Keep as-is (text button with label)
                              FilledButton.icon(
                                onPressed: onHire,
                                icon: SizedBox.square(
                                  dimension: 20, // matches typical icon size
                                  child: Image.asset(
                                    'assets/gmail.png',
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (_, __, ___) =>
                                            const Icon(Icons.mail_outline),
                                  ),
                                ),
                                label: const Text('Work with me'),
                              ),

                              const SizedBox(width: 10),

                              // GitHub (image-based)
                              _ImageActionButton(
                                asset:
                                    'assets/github.png', // <- your asset path
                                tooltip: 'GitHub',
                                semanticsLabel: 'Open GitHub',
                                onTap: onGitHub,
                                size: 42,
                              ),

                              const SizedBox(width: 8),

                              // LinkedIn (image-based)
                              _ImageActionButton(
                                asset:
                                    'assets/linkedin2.png', // <- your asset path
                                tooltip: 'LinkedIn',
                                semanticsLabel: 'Open LinkedIn',
                                onTap: onLinkedIn,
                                size: 42,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        _SkillChips(
                          skills: const [
                            'Flutter',
                            'Dart',
                            'Firebase',
                            'Node',
                            'Python',
                            'Vertex/Gemini',
                            'ML/NLP',
                            'IoT (ESP32-CAM)',
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBlob extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final Color color;
  final double dx, dy;
  const _AnimatedBlob({
    required this.controller,
    required this.size,
    required this.color,
    required this.dx,
    required this.dy,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value * 2 * math.pi;
        final shiftX = math.sin(t + dx) * 30;
        final shiftY = math.cos(t + dy) * 24;
        return Align(
          alignment: Alignment(dx + shiftX / 300, dy + shiftY / 300),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color.withOpacity(0.35), Colors.transparent],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: size * 0.6,
                  spreadRadius: size * 0.08,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// ---------- ABOUT ----------
class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyLarge;
    return _Section(
      title: 'ABOUT',
      child: _Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "I’m a product-minded engineer focused on AI-powered Flutter apps.\n"
              "I enjoy taking ideas from zero → launch: crisp UX, solid architecture, and fast execution.",
              style: body,
            ),
            const SizedBox(height: 14),
            const _InfoRow(
              label: 'Tech',
              value: 'Flutter · Dart · Firebase · Node · Python · Gemini',
            ),
            const _InfoRow(label: 'Focus', value: 'AI/ML, Mobile, Web, IoT'),
            const _InfoRow(label: 'Base', value: 'Belagavi, Karnataka, India'),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: labelStyle)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

/// ---------- EXPERIENCE ----------
class _Experience extends StatelessWidget {
  const _Experience();
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < _Bp.mobile;

    final items = const [
      _ExpItem(
        title: 'VanLoka — Software Engineer Intern (Flutter)',
        when: 'Aug 2024 – Jan 2025 · Hybrid, India',
        bullets: [
          'Built & optimized two Flutter apps (Parent & Partner); 50%+ UX improvement using MVP/MVVM, Riverpod/Provider, and Clean Architecture.',
          'Integrated Google Maps, WhatsApp QR, Bluetooth Beacon, and Firebase OTP for real-time tracking & engagement.',
          'Implemented push notifications, telemetry, and monitoring dashboards to improve reliability & performance.',
          'Designed CI/CD pipelines with automated tests for scalable, production-ready Play Store deployments.',
        ],
        tags: [
          'Flutter',
          'Riverpod',
          'MVVM',
          'MVP',
          'Clean Arch',
          'Firebase',
          'Maps',
          'Beacon',
          'CI/CD',
        ],
      ),
      _ExpItem(
        title: 'Prodigy Infotech — Machine Learning Intern',
        when: 'Jun 2024 – Jul 2024 · Remote, India',
        bullets: [
          'Developed ML models (Linear Regression, K-Means, SVM, CNN) for hand-gesture recognition with preprocessing and tuning.',
          'Supervised/unsupervised learning + computer vision using Python, scikit-learn, and OpenCV.',
        ],
        tags: ['Python', 'Scikit-learn', 'OpenCV', 'SVM', 'CNN', 'K-Means'],
      ),
      _ExpItem(
        title: 'KalVin Techsol — Computer Vision Intern',
        when: 'Oct 2023 – Feb 2024 · Remote, India',
        bullets: [
          'Designed & deployed a YOLOv8-based weed detection system with 90%+ accuracy for smart farming.',
          'Implemented real-time event streaming with MQTT for sensor data communication & monitoring.',
          'Containerized applications with Docker for scalable, cloud-native deployment.',
          'Applied Python, OpenCV, and ML workflows to automate agricultural processes.',
        ],
        tags: [
          'YOLOv8',
          'MQTT',
          'Docker',
          'Computer Vision',
          'Python',
          'OpenCV',
        ],
      ),
    ];

    return _Section(
      title: 'EXPERIENCE',
      child: _Glass(
        padding: const EdgeInsets.all(0),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                Stack(
                  children: [
                    // Timeline line
                    if (!isMobile && i < items.length - 1)
                      Positioned(
                        left: 24,
                        top: 38,
                        bottom: -8,
                        child: Container(
                          width: 2,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.08),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 0,
                        right: 0,
                        top: 4,
                        bottom: 4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dot
                          if (!isMobile)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 10,
                                right: 16,
                                left: 16,
                              ),
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.4),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          Expanded(child: items[i]),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpItem extends StatefulWidget {
  final String title, when;
  final List<String> bullets;
  final List<String> tags;
  const _ExpItem({
    required this.title,
    required this.when,
    required this.bullets,
    required this.tags,
  });

  @override
  State<_ExpItem> createState() => _ExpItemState();
}

class _ExpItemState extends State<_ExpItem> {
  bool open = false;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => open = !open),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.when,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              const SizedBox(height: 10),
              _ChipScroller(tags: widget.tags),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState:
                    open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    children:
                        widget.bullets
                            .map(
                              (b) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('•  '),
                                    Expanded(child: Text(b)),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------- PROJECTS ----------

// ===================== PROJECTS =====================
class _Projects extends StatelessWidget {
  const _Projects();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < _Bp.mobile;
    final isTablet = w >= _Bp.mobile && w < _Bp.tablet;

    final cards = const [
      _ProjectCard(
        title: 'NexaBill — Smart Billing & Fraud Prevention',
        images: [
          'assets/nb1.jpeg',
          'assets/nb2.jpeg',
          'assets/nb3.jpeg',
          'assets/nb4.jpeg',
          'assets/nb5.jpeg',
          'assets/nb6.jpeg',
        ],
        desc:
            'Multi-role retail billing app with QR/voice input, AI receipt parsing, IoT fraud checks, and payments.',
        tags: [
          'Flutter',
          'Firebase Auth',
          'Firestore',
          'Realtime DB',
          'Riverpod/Provider',
          'Gemini AI',
          'Razorpay',
          'ESP32-CAM',
        ],
        githubUrl: 'https://github.com/rohitarer',
        details: [
          'Built Admin/Cashier/Customer apps with dashboards, QR billing, and OTP verification.',
          'Integrated Razorpay for payments and Gemini AI for smart input (voice, text, scan).',
          'ESP32-CAM object-check IoT step to prevent fraud before payment.',
          'Deployed with Firebase Auth, Firestore, and Realtime DB; Play Console (closed testing).',
        ],
      ),
      _ProjectCard(
        title: 'NexaBill Website — Showcase & Self-Billing',
        images: [
          'assets/nbw1.png',
          'assets/nbw2.png',
          'assets/nbw3.png',
          'assets/nbw4.png',
          'assets/nbw5.png',
          'assets/nbw6.png',
        ],
        desc:
            'Public website for NexaBill with concept overview, pitch-deck viewer, and open self-billing to generate PDF invoices.',
        tags: ['Website', 'Vercel', 'Self-Billing', 'PDF', 'Presentation'],
        siteUrl: 'https://www.nexabill.in',
        githubUrl: 'https://github.com/rohitarer',
        details: [
          'Showcases the NexaBill concept and product overview.',
          'Hosted on Vercel at nexabill.in for fast, secure delivery.',
          'Includes a pitch deck presented in a “project overview / presentation” UI.',
          'Offers an open Self-Billing tool so anyone can create customized invoices.',
          'Invoices can be downloaded as PDF with subtle “Powered by NexaBill” branding.',
        ],
      ),
      _ProjectCard(
        title: 'Memscape — GeoTime Photo Network',
        images: [
          'assets/m1.jpeg',
          'assets/m2.jpeg',
          'assets/m3.jpeg',
          'assets/m4.jpeg',
        ],
        desc:
            'Map-first app to publish & discover memories by place and time with private, “anti-social” chat.',
        tags: [
          'Flutter',
          'Firebase Auth',
          'Firestore',
          'Realtime DB',
          'OpenStreetMap',
          'OpenRouteService',
        ],
        githubUrl: 'https://github.com/rohitarer',
        details: [
          'Geo-tagged photo publishing with discovery by location/time and routing filters.',
          'Riverpod/Provider state mgmt; shipped to Google Play (closed testing).',
          'Privacy-first chat between co-visited users; Firestore channels, rules, read receipts/typing, optional ephemeral.',
        ],
      ),
    ];

    // ---- MOBILE: keep your compact PageView carousel (bounded height)
    final viewportWidth = MediaQuery.of(context).size.width;
    const mobileImageAspect = 2.4; // wider banner to save vertical space
    final imageH = (viewportWidth * 0.92) / mobileImageAspect;
    final baseTextH =
        236.0 * MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.2);
    final mobileCarouselHeight = (imageH + baseTextH + 12).clamp(420.0, 520.0);

    Widget mobileCarousel() {
      return _Glass(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          height: mobileCarouselHeight.toDouble(),
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.92),
            itemCount: cards.length,
            itemBuilder:
                (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: cards[i],
                ),
          ),
        ),
      );
    }

    // ---- WEB/TABLET/DESKTOP: horizontal scroller with mouse/trackpad drag
    final behavior = const MaterialScrollBehavior().copyWith(
      dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      },
    );

    // Card size tuned to avoid vertical overflow and keep things snappy
    final cardWidth = isTablet ? 380.0 : 420.0;
    final laneHeight = isTablet ? 520.0 : 560.0;

    Widget desktopHorizontal() {
      return ScrollConfiguration(
        behavior: behavior,
        child: SizedBox(
          height: laneHeight, // <- bounds the height inside your Column
          child: Scrollbar(
            interactive: true,
            thumbVisibility: kIsWeb, // show thumb on web
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder:
                  (_, i) => SizedBox(width: cardWidth, child: cards[i]),
            ),
          ),
        ),
      );
    }

    return _Section(
      title: 'PROJECTS',
      // Use horizontal scroller on web/desktop; PageView on mobile
      child: isMobile ? mobileCarousel() : desktopHorizontal(),
    );
  }
}

// ===================== PROJECT CARD (unchanged behavior) =====================
class _ProjectCard extends StatefulWidget {
  final String title, desc;
  final List<String> images;
  final List<String> tags;
  final List<String>? details; // long bullets (optional)
  final String? siteUrl; // website (optional)
  final String? githubUrl; // repo (optional)

  const _ProjectCard({
    required this.title,
    required this.images,
    required this.desc,
    required this.tags,
    this.details,
    this.siteUrl,
    this.githubUrl,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
  bool hover = false;
  bool open = false;

  late final PageController _imgCtrl;
  int _imgIndex = 0;

  @override
  void initState() {
    super.initState();
    _imgCtrl = PageController();
  }

  @override
  void dispose() {
    _imgCtrl.dispose();
    super.dispose();
  }

  void _showDetailsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return _ProjectDetailsSheet(
          title: widget.title,
          images: widget.images,
          desc: widget.desc,
          tags: widget.tags,
          details: widget.details,
          siteUrl: widget.siteUrl,
          githubUrl: widget.githubUrl,
        );
      },
    );
  }

  void _openFullscreenGallery(int startIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _FullscreenGallery(
              images: widget.images,
              initialIndex: startIndex,
              heroPrefix: widget.title,
            ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < _Bp.mobile;

    final content = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inline image carousel
          AspectRatio(
            aspectRatio: isMobile ? 1.6 : 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _imgCtrl,
                  itemCount: (widget.images.isEmpty ? 1 : widget.images.length),
                  onPageChanged: (i) => setState(() => _imgIndex = i),
                  itemBuilder: (_, i) {
                    if (widget.images.isEmpty) {
                      return Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
                      );
                    }
                    final path = widget.images[i % widget.images.length];
                    return GestureDetector(
                      onTap: () => _openFullscreenGallery(i),
                      child: Hero(
                        tag: '${widget.title}_$i',
                        child: Image.asset(
                          path,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _Dots(
                    count: widget.images.length,
                    index: _imgIndex.clamp(
                      0,
                      (widget.images.length - 1).clamp(0, 999),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Text content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChipScroller(tags: widget.tags),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.desc,
                  maxLines: isMobile ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.35,
                    letterSpacing: 0.2,
                  ),
                ),

                // Expandable details (desktop/tablet only)
                if (!isMobile && (widget.details?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 8),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 180),
                    crossFadeState:
                        open
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Column(
                      children:
                          widget.details!
                              .map(
                                (b) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('•  '),
                                      Expanded(child: Text(b)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  // Align(
                  //   alignment: Alignment.centerLeft,
                  //   child: TextButton.icon(
                  //     onPressed: () => setState(() => open = !open),
                  //     icon: Icon(open ? Icons.expand_less : Icons.expand_more),
                  //     label: Text(open ? 'Less' : 'More'),
                  //   ),
                  // ),
                ],

                // Actions row
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (widget.siteUrl != null)
                      _ImageActionButton(
                        asset: 'assets/web.png',
                        tooltip: 'Website',
                        semanticsLabel: 'Open website',
                        onTap: () => _open(widget.siteUrl!),
                      ),
                    if (widget.githubUrl != null) ...[
                      const SizedBox(width: 6),
                      _ImageActionButton(
                        asset: 'assets/github.png',
                        tooltip: 'GitHub',
                        semanticsLabel: 'Open GitHub',
                        onTap: () => _open(widget.githubUrl!),
                      ),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: _showDetailsSheet,
                      child: const Text('View'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final wrapped = AnimatedScale(
      scale: hover ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          boxShadow:
              hover
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                  : [],
        ),
        child: content,
      ),
    );

    return _Tilt3D(
      glowOpacity: 0.12,
      child: MouseRegion(
        onEnter: (_) => setState(() => hover = true),
        onExit: (_) => setState(() => hover = false),
        child: wrapped,
      ),
    );
  }
}

// ===================== DETAILS SHEET =====================
class _ProjectDetailsSheet extends StatefulWidget {
  final String title, desc;
  final List<String> images;
  final List<String> tags;
  final List<String>? details;
  final String? siteUrl, githubUrl;

  const _ProjectDetailsSheet({
    super.key,
    required this.title,
    required this.images,
    required this.desc,
    required this.tags,
    this.details,
    this.siteUrl,
    this.githubUrl,
  });

  @override
  State<_ProjectDetailsSheet> createState() => _ProjectDetailsSheetState();
}

class _ProjectDetailsSheetState extends State<_ProjectDetailsSheet> {
  late final PageController _ctrl;
  int _idx = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _FullscreenGallery(
              images: widget.images,
              initialIndex: _idx,
              heroPrefix: widget.title,
            ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width;
    final isNarrow = maxW < 560;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PageView.builder(
                          controller: _ctrl,
                          itemCount:
                              (widget.images.isEmpty
                                  ? 1
                                  : widget.images.length),
                          onPageChanged: (i) => setState(() => _idx = i),
                          itemBuilder: (_, i) {
                            if (widget.images.isEmpty) {
                              return Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                              );
                            }
                            final path =
                                widget.images[i % widget.images.length];
                            return GestureDetector(
                              onTap: _openFullscreen,
                              child: Hero(
                                tag: '${widget.title}_$i',
                                child: Image.asset(
                                  path,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                ),
                              ),
                            );
                          },
                        ),
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: _Dots(
                            count: widget.images.length,
                            index: _idx.clamp(
                              0,
                              (widget.images.length - 1).clamp(0, 999),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (widget.siteUrl != null)
                      _ImageActionButton(
                        asset: 'assets/icons/web.png',
                        tooltip: 'Website',
                        semanticsLabel: 'Open website',
                        onTap: () => _open(widget.siteUrl!),
                        size: 44,
                      ),
                    if (widget.githubUrl != null) ...[
                      const SizedBox(width: 6),
                      _ImageActionButton(
                        asset: 'assets/icons/github.png',
                        tooltip: 'GitHub',
                        semanticsLabel: 'Open GitHub',
                        onTap: () => _open(widget.githubUrl!),
                        size: 44,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _ChipScroller(tags: widget.tags),
                const SizedBox(height: 12),
                Text(
                  widget.desc,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
                if (widget.details != null && widget.details!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final d in widget.details!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [const Text('•  '), Expanded(child: Text(d))],
                      ),
                    ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: isNarrow ? Alignment.center : Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.check),
                    label: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== FULLSCREEN GALLERY (pinch-zoom + swipe) =====================
class _FullscreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  final String heroPrefix;

  const _FullscreenGallery({
    required this.images,
    required this.initialIndex,
    required this.heroPrefix,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _pc;

  @override
  void initState() {
    super.initState();
    _pc = PageController(
      initialPage: widget.initialIndex.clamp(0, widget.images.length - 1),
    );
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: widget.images.length,
            itemBuilder:
                (_, i) => Center(
                  child: Hero(
                    tag: '${widget.heroPrefix}_$i',
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Image.asset(widget.images[i], fit: BoxFit.contain),
                    ),
                  ),
                ),
          ),
          // Close button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          // Subtle gradient overlay at top for legibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 100,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== DOT INDICATOR =====================
class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    if (count <= 1) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final active = i == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: active ? 14 : 6,
              decoration: BoxDecoration(
                color: active ? c.primary : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ===================== TAGS =====================
class _ChipScroller extends StatelessWidget {
  final List<String> tags;
  const _ChipScroller({required this.tags});
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final t in tags)
            Padding(padding: const EdgeInsets.only(right: 8), child: _Tag(t)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.primary.withOpacity(0.15)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// ---------- CONTACT ----------
class _Contact extends StatelessWidget {
  const _Contact();

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < _Bp.mobile;

    // Actions as horizontal scroller using your image buttons
    Widget _actions() {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _ImageActionButton(
              asset: 'assets/gmail.png',
              tooltip: 'Email',
              semanticsLabel: 'Email',
              onTap: () => _open('mailto:rohitarer00@gmail.com'),
            ),
            const SizedBox(width: 10),
            _ImageActionButton(
              asset: 'assets/linkedin2.png',
              tooltip: 'LinkedIn',
              semanticsLabel: 'LinkedIn',
              onTap:
                  () => _open(
                    'https://www.linkedin.com/in/rohit-arer-a96294214/',
                  ),
            ),
          ],
        ),
      );
    }

    final contactCard = _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Let’s build something great together.',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'I’m open to freelance, collabs, and full-time roles.\n'
            'Prefer an intro? Drop a line and I’ll respond quickly.',
          ),
          const SizedBox(height: 16),
          _actions(),
        ],
      ),
    );

    final quickInfoCard = _Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Info',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const _InfoRow(label: 'Timezone', value: 'IST (UTC+05:30)'),
          const _InfoRow(
            label: 'Languages',
            value: 'English · Hindi · Marwadi (a little)',
          ),
          const _InfoRow(label: 'Status', value: 'Available for new work'),
        ],
      ),
    );

    return _Section(
      title: 'CONTACT',
      child:
          isMobile
              // MOBILE: horizontal scroller with both cards
              ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    SizedBox(width: w * 0.9, child: contactCard),
                    const SizedBox(width: 12),
                    SizedBox(width: w * 0.9, child: quickInfoCard),
                    const SizedBox(width: 8),
                  ],
                ),
              )
              // DESKTOP/TABLET: two-column layout
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: contactCard),
                  const SizedBox(width: 16),
                  Expanded(flex: 4, child: quickInfoCard),
                ],
              ),
    );
  }
}

/// ---------- FOOTER ----------
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            '© ${DateTime.now().year} Rohit Arer — All rights reserved',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _ImageActionButton(
                asset:
                    'assets/github.png', // adjust if your path is assets/icons/github.png
                tooltip: 'GitHub',
                semanticsLabel: 'GitHub',
                onTap: () => _open('https://github.com/rohitarer'),
                size: 44,
              ),
              _ImageActionButton(
                asset: 'assets/linkedin2.png',
                tooltip: 'LinkedIn',
                semanticsLabel: 'LinkedIn',
                onTap:
                    () => _open(
                      'https://www.linkedin.com/in/rohit-arer-a96294214/',
                    ),
                size: 44,
              ),
              _ImageActionButton(
                asset: 'assets/gmail.png',
                tooltip: 'Email',
                semanticsLabel: 'Email',
                onTap: () => _open('mailto:rohitarer00@gmail.com'),
                size: 44,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ---------- SHARED WIDGETS ----------
class _SectionPad extends StatelessWidget {
  final Widget child;
  const _SectionPad({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: child,
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.08),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Glass({required this.child, this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SkillChips extends StatelessWidget {
  final List<String> skills;
  const _SkillChips({required this.skills});

  @override
  Widget build(BuildContext context) {
    // Enable horizontal drag with mouse/trackpad on web
    final behavior = const MaterialScrollBehavior().copyWith(
      dragDevices: {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      },
    );

    return ScrollConfiguration(
      behavior: behavior,
      child: SizedBox(
        height: 36, // fixed height so it won't push/overlap sections
        width: double.infinity, // constrain to available width
        child: Scrollbar(
          interactive: true,
          thumbVisibility: kIsWeb, // show thumb on web
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: skills.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) => Chip(label: Text(skills[i])),
          ),
        ),
      ),
    );
  }
}

class _Tilt3D extends StatefulWidget {
  final Widget child;
  final double maxTilt; // degrees
  final double glowOpacity;
  const _Tilt3D({
    super.key,
    required this.child,
    this.maxTilt = 10,
    this.glowOpacity = 0.18,
  });

  @override
  State<_Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<_Tilt3D> {
  double _dx = 0, _dy = 0; // -1..1

  void _update(Offset p, Size s) {
    final x = (p.dx / s.width) * 2 - 1;
    final y = (p.dy / s.height) * 2 - 1;
    setState(() {
      _dx = x.clamp(-1, 1);
      _dy = y.clamp(-1, 1);
    });
  }

  void _reset() => setState(() {
    _dx = 0;
    _dy = 0;
  });

  @override
  Widget build(BuildContext context) {
    final tiltX = -_dy * widget.maxTilt * math.pi / 180;
    final tiltY = _dx * widget.maxTilt * math.pi / 180;
    final glow = BoxShadow(
      color: Theme.of(
        context,
      ).colorScheme.primary.withOpacity(widget.glowOpacity),
      blurRadius: 30,
      spreadRadius: 1,
      offset: Offset(_dx * 12, _dy * 12),
    );

    return LayoutBuilder(
      builder: (context, c) {
        return MouseRegion(
          onHover: (e) => _update(e.localPosition, c.biggest),
          onExit: (_) => _reset(),
          child: GestureDetector(
            onPanUpdate: (e) => _update(e.localPosition, c.biggest),
            onPanEnd: (_) => _reset(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(boxShadow: [glow]),
              child: Transform(
                alignment: Alignment.center,
                transform:
                    Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(tiltX)
                      ..rotateY(tiltY),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ---------- HELPERS ----------
Future<void> _copy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Copied: $text'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
