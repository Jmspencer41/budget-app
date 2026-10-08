import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';

class AppColors {
  static const paper = Color(0xFF070B14);
  static const paperDim = Color(0xFF121A2C);
  static const bgGlow = Color(0xFF16213B);
  static const ink = Color(0xFFEDEFF5);
  static const inkFade = Color(0xFF8C96B3);
  static const hairline = Color(0xFF232C44);
  static const moss = Color(0xFF4FD1A5);
  static const rust = Color(0xFFFF6B5B);
  static const gold = Color(0xFFF2C14E);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.paper,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.moss,
      brightness: Brightness.dark,
      surface: AppColors.paperDim,
    ),
    dividerColor: AppColors.hairline,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink)
        .copyWith(
          headlineSmall: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 26,
            letterSpacing: -0.2,
            color: AppColors.ink,
          ),
          titleMedium: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.ink,
          ),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.inkFade),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.paperDim),
    inputDecorationTheme: const InputDecorationTheme(
      labelStyle: TextStyle(color: AppColors.inkFade),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.hairline)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.moss)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.moss,
        foregroundColor: AppColors.paper,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.paper,
      indicatorColor: AppColors.paperDim,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(fontSize: 12, color: selected ? AppColors.ink : AppColors.inkFade);
      }),
    ),
  );
}

TextStyle ledgerNumber({
  double size = 15,
  FontWeight weight = FontWeight.w600,
  Color color = AppColors.ink,
}) {
  return TextStyle(
    fontFamily: 'monospace',
    fontFeatures: const [FontFeature.tabularFigures()],
    fontSize: size,
    fontWeight: weight,
    color: color,
  );
}

class _Starfield extends StatelessWidget {
  const _Starfield();

  static final math.Random _rand = math.Random(7);
  static final List<Offset> _positions = List.generate(90, (_) => Offset(_rand.nextDouble(), _rand.nextDouble()));
  static final List<double> _radii = List.generate(90, (_) => _rand.nextDouble() * 1.3 + 0.4);
  static final List<double> _opacities = List.generate(90, (_) => _rand.nextDouble() * 0.5 + 0.15);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarfieldPainter(_positions, _radii, _opacities),
      size: Size.infinite,
    );
  }
}

class _StarfieldPainter extends CustomPainter {
  final List<Offset> positions;
  final List<double> radii;
  final List<double> opacities;

  _StarfieldPainter(this.positions, this.radii, this.opacities);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < positions.length; i++) {
      final paint = Paint()..color = Colors.white.withValues(alpha: opacities[i]);
      canvas.drawCircle(
        Offset(positions[i].dx * size.width, positions[i].dy * size.height),
        radii[i],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter oldDelegate) => false;
}

class SpaceBackground extends StatelessWidget {
  final Widget child;

  const SpaceBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.7, -0.9),
                radius: 1.3,
                colors: [AppColors.bgGlow, AppColors.paper],
              ),
            ),
          ),
        ),
        const Positioned.fill(child: IgnorePointer(child: _Starfield())),
        child,
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onAdd;
  final Key? addKey;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onAdd,
    this.addKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null)
            Text(trailing!, style: ledgerNumber(size: 13, color: AppColors.inkFade)),
          if (onAdd != null)
            InkWell(
              key: addKey,
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(Icons.add_circle_outline, size: 20, color: AppColors.moss),
              ),
            ),
        ],
      ),
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.hairline);
  }
}

class RoleBadge extends StatelessWidget {
  final BudgetRole role;

  const RoleBadge({super.key, required this.role});

  Color get _color {
    switch (role) {
      case BudgetRole.owner:
        return AppColors.moss;
      case BudgetRole.editor:
        return AppColors.gold;
      case BudgetRole.viewer:
        return AppColors.inkFade;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: _color),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        role.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color),
      ),
    );
  }
}

class RowAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const RowAction({super.key, required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 17, color: color ?? AppColors.inkFade),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final String text;

  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Text(text, style: const TextStyle(color: AppColors.inkFade)),
    );
  }
}
