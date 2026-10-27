import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Identidade visual do InduSense, tirada da logo:
/// azul-marinho profundo, azul elétrico e ciano.
class AppColors {
  AppColors._();

  // Marca
  static const Color navy = Color(0xFF050B1A);
  static const Color navy2 = Color(0xFF0A1A3F);
  static const Color electric = Color(0xFF2F7BFF);
  static const Color cyan = Color(0xFF22D3C5);

  // Modo escuro
  static const Color darkBackground = Color(0xFF060C1C);
  static const Color darkCard = Color(0xFF0E1830);
  static const Color darkBorder = Color(0xFF1C2A4A);

  // Modo claro
  static const Color primary = Color(0xFF0A1A3F);
  static const Color primaryDark = Color(0xFF050B1A);
  static const Color accent = Color(0xFF1E6BFF);
  static const Color background = Color(0xFFF4F8FD);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0A1A3F);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color divider = Color(0xFFE6EDF7);

  // Status dos sensores / alertas
  static const Color statusNormal = Color(0xFF10B981);
  static const Color statusAtencao = Color(0xFFF59E0B);
  static const Color statusCritico = Color(0xFFEF4444);
  static const Color statusOffline = Color(0xFF94A3B8);
}

class AppGradients {
  AppGradients._();

  /// Degradê da marca (botões principais, destaques).
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E5BFF), Color(0xFF2F7BFF), Color(0xFF22D3C5)],
  );

  /// Fundo da splash e do login.
  static const LinearGradient night = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A1A3F), Color(0xFF050B1A), Color(0xFF03060F)],
  );

  /// Cartões de destaque: o mesmo azul → ciano do botão "Entrar".
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1061FF), Color(0xFF1E8BFF), Color(0xFF14C8E6)],
  );

  /// Fundo das telas claras (igual ao login).
  static const LinearGradient fundoClaro = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF7FAFE), Color(0xFFEAF2FE)],
  );
}

class AppTheme {
  AppTheme._();

  static const _transicoes = PageTransitionsTheme(builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  });

  static ThemeData _base({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color text,
    required Color border,
  }) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.electric,
      brightness: brightness,
      primary: AppColors.electric,
      secondary: AppColors.cyan,
      surface: surface,
    );

    OutlineInputBorder borda(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: surface,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: _transicoes,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: dark ? BorderSide(color: border) : BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF0B1426) : Colors.white,
        hintStyle: const TextStyle(color: Color(0xFF7C8AA5), fontSize: 14),
        prefixIconColor: const Color(0xFF7C8AA5),
        suffixIconColor: const Color(0xFF7C8AA5),
        border: borda(border),
        enabledBorder: borda(border),
        focusedBorder: borda(AppColors.electric, 1.6),
        errorBorder: borda(AppColors.statusCritico),
        focusedErrorBorder: borda(AppColors.statusCritico, 1.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.electric,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electric,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark ? AppColors.cyan : AppColors.electric,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: border),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.electric : null),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.electric),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF16233F) : AppColors.primary,
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }

  static ThemeData get light => _base(
        brightness: Brightness.light,
        bg: AppColors.background,
        surface: AppColors.surface,
        text: AppColors.textPrimary,
        border: const Color(0xFFE3EBF6),
      );

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        bg: AppColors.darkBackground,
        surface: AppColors.darkCard,
        text: Colors.white,
        border: AppColors.darkBorder,
      );
}

/// Mapeia o status de um sensor/alerta para a cor correspondente.
Color statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'normal':
      return AppColors.statusNormal;
    case 'atencao':
    case 'atenção':
      return AppColors.statusAtencao;
    case 'critico':
    case 'crítico':
      return AppColors.statusCritico;
    default:
      return AppColors.statusOffline;
  }
}
