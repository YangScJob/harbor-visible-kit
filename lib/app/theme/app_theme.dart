import 'package:flutter/material.dart';

/// Harbor Visible Kit theme design system with dark and light modes.
class AppTheme {
  AppTheme._();

  // Dark theme color tokens.
  static const Color deepSea = Color(0xFF07111D);
  static const Color harborBlue = Color(0xFF1677A8);
  static const Color cyanUpload = Color(0xFF18C4D8);
  static const Color dockWhite = Color(0xFFEAF7FF);
  static const Color background = deepSea;
  static const Color surface = Color(0xFF0C1A29);
  static const Color surfaceLight = Color(0xFF11263A);
  static const Color surfaceBorder = Color(0xFF1E3A4E);
  static const Color primary = harborBlue;
  static const Color primaryDim = Color(0xFF0E3148);
  static const Color upload = cyanUpload;
  static const Color uploadDim = Color(0xFF083944);
  static const Color success = Color(0xFF3CBF7B);
  static const Color successDim = Color(0xFF102F2A);
  static const Color warning = Color(0xFFE1A743);
  static const Color warningDim = Color(0xFF3C2E12);
  static const Color error = Color(0xFFFF6A5F);
  static const Color errorDim = Color(0xFF3F1C1E);
  static const Color textPrimary = dockWhite;
  static const Color textSecondary = Color(0xFF9CB4C6);
  static const Color textMuted = Color(0xFF5F7488);
  static const Color divider = Color(0xFF1A3245);
  static const Color terminal = Color(0xFF050B12);

  // Light theme color tokens.
  static const Color lBackground = Color(0xFFEEF4F8);
  static const Color lSurface = Color(0xFFFAFDFF);
  static const Color lSurfaceLight = Color(0xFFE8F2F8);
  static const Color lSurfaceBorder = Color(0xFFC6D6E2);
  static const Color lPrimary = Color(0xFF0F668F);
  static const Color lPrimaryDim = Color(0xFFD7EDF7);
  static const Color lUpload = Color(0xFF009FB8);
  static const Color lUploadDim = Color(0xFFD5F5F8);
  static const Color lSuccess = Color(0xFF1A7A4B);
  static const Color lSuccessDim = Color(0xFFDDF4E7);
  static const Color lWarning = Color(0xFF946200);
  static const Color lWarningDim = Color(0xFFFFF1CE);
  static const Color lError = Color(0xFFC93A35);
  static const Color lErrorDim = Color(0xFFFFE5E3);
  static const Color lTextPrimary = Color(0xFF102231);
  static const Color lTextSecondary = Color(0xFF4F6475);
  static const Color lTextMuted = Color(0xFF8495A3);
  static const Color lDivider = Color(0xFFC7D5E0);
  static const Color lTerminal = Color(0xFFF6FAFC);

  // Border radii.
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;

  // Sidebar dimensions.
  static const double sidebarWidth = 230.0;

  // Animation timings.
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);
  static const Duration themeTransition = Duration(milliseconds: 360);
  static const Curve themeCurve = Curves.easeInOutCubic;

  // Semantic color helpers by brightness.
  static Color bg(Brightness b) =>
      b == Brightness.dark ? background : lBackground;
  static Color surf(Brightness b) => b == Brightness.dark ? surface : lSurface;
  static Color surfL(Brightness b) =>
      b == Brightness.dark ? surfaceLight : lSurfaceLight;
  static Color surfBorder(Brightness b) =>
      b == Brightness.dark ? surfaceBorder : lSurfaceBorder;
  static Color prim(Brightness b) => b == Brightness.dark ? primary : lPrimary;
  static Color primDim(Brightness b) =>
      b == Brightness.dark ? primaryDim : lPrimaryDim;
  static Color upl(Brightness b) => b == Brightness.dark ? upload : lUpload;
  static Color uplDim(Brightness b) =>
      b == Brightness.dark ? uploadDim : lUploadDim;
  static Color terminalBg(Brightness b) =>
      b == Brightness.dark ? terminal : lTerminal;
  static Color suc(Brightness b) => b == Brightness.dark ? success : lSuccess;
  static Color sucDim(Brightness b) =>
      b == Brightness.dark ? successDim : lSuccessDim;
  static Color warn(Brightness b) => b == Brightness.dark ? warning : lWarning;
  static Color warnDim(Brightness b) =>
      b == Brightness.dark ? warningDim : lWarningDim;
  static Color err(Brightness b) => b == Brightness.dark ? error : lError;
  static Color errDim(Brightness b) =>
      b == Brightness.dark ? errorDim : lErrorDim;
  static Color textP(Brightness b) =>
      b == Brightness.dark ? textPrimary : lTextPrimary;
  static Color textS(Brightness b) =>
      b == Brightness.dark ? textSecondary : lTextSecondary;
  static Color textM(Brightness b) =>
      b == Brightness.dark ? textMuted : lTextMuted;
  static Color div(Brightness b) => b == Brightness.dark ? divider : lDivider;

  // Context-aware card decorations.
  static BoxDecoration cardDeco(Brightness b) => BoxDecoration(
    color: surf(b),
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: surfBorder(b)),
  );

  static BoxDecoration cardDecoHover(Brightness b) => BoxDecoration(
    color: surfL(b),
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: upl(b).withValues(alpha: 0.32)),
    boxShadow: [
      BoxShadow(color: upl(b).withValues(alpha: 0.07), blurRadius: 14),
    ],
  );

  // Legacy static accessors kept for existing call sites.
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: surfaceBorder),
  );

  static BoxDecoration get cardDecorationHover => BoxDecoration(
    color: surfaceLight,
    borderRadius: BorderRadius.circular(radiusMd),
    border: Border.all(color: upload.withValues(alpha: 0.32)),
    boxShadow: [
      BoxShadow(color: upload.withValues(alpha: 0.07), blurRadius: 14),
    ],
  );

  // Dark ThemeData.
  static ThemeData get darkTheme {
    final baseText = ThemeData.dark().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      focusColor: upload.withValues(alpha: 0.16),
      hoverColor: upload.withValues(alpha: 0.08),
      splashColor: upload.withValues(alpha: 0.14),
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: primary,
        secondary: upload,
        error: error,
        onSurface: textPrimary,
        onPrimary: background,
      ),
      textTheme: _buildTextTheme(baseText, Brightness.dark),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: surfaceBorder),
        ),
      ),
      inputDecorationTheme: _buildInputTheme(Brightness.dark),
      elevatedButtonTheme: _buildElevatedBtnTheme(Brightness.dark),
      outlinedButtonTheme: _buildOutlinedBtnTheme(Brightness.dark),
      textButtonTheme: _buildTextBtnTheme(Brightness.dark),
      iconButtonTheme: _buildIconBtnTheme(Brightness.dark),
      popupMenuTheme: _buildPopupMenuTheme(Brightness.dark),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceLight,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: divider),
        ),
        textStyle: const TextStyle(color: textPrimary, fontSize: 12),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            borderSide: const BorderSide(color: divider),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return upload;
          return Colors.transparent;
        }),
        overlayColor: _stateLayer(Brightness.dark, upload),
        checkColor: WidgetStateProperty.all(background),
        side: const BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  // Light ThemeData.
  static ThemeData get lightTheme {
    final baseText = ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lBackground,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      focusColor: lUpload.withValues(alpha: 0.14),
      hoverColor: lUpload.withValues(alpha: 0.08),
      splashColor: lUpload.withValues(alpha: 0.12),
      colorScheme: const ColorScheme.light(
        surface: lSurface,
        primary: lPrimary,
        secondary: lUpload,
        error: lError,
        onSurface: lTextPrimary,
        onPrimary: Colors.white,
      ),
      textTheme: _buildTextTheme(baseText, Brightness.light),
      cardTheme: CardThemeData(
        color: lSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: lSurfaceBorder),
        ),
      ),
      inputDecorationTheme: _buildInputTheme(Brightness.light),
      elevatedButtonTheme: _buildElevatedBtnTheme(Brightness.light),
      outlinedButtonTheme: _buildOutlinedBtnTheme(Brightness.light),
      textButtonTheme: _buildTextBtnTheme(Brightness.light),
      iconButtonTheme: _buildIconBtnTheme(Brightness.light),
      popupMenuTheme: _buildPopupMenuTheme(Brightness.light),
      dividerTheme: const DividerThemeData(
        color: lDivider,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: lSurfaceLight,
          borderRadius: BorderRadius.circular(radiusSm),
          border: Border.all(color: lDivider),
        ),
        textStyle: const TextStyle(color: lTextPrimary, fontSize: 12),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: lSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusSm),
            borderSide: const BorderSide(color: lDivider),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return lUpload;
          return Colors.transparent;
        }),
        overlayColor: _stateLayer(Brightness.light, lUpload),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: lDivider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  // Private theme builder helpers.

  static TextTheme _buildTextTheme(TextTheme base, Brightness b) {
    final tp = b == Brightness.dark ? textPrimary : lTextPrimary;
    final ts = b == Brightness.dark ? textSecondary : lTextSecondary;
    final tm = b == Brightness.dark ? textMuted : lTextMuted;
    return base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(
        color: tp,
        fontWeight: FontWeight.w700,
        fontSize: 28,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        color: tp,
        fontWeight: FontWeight.w600,
        fontSize: 22,
      ),
      titleLarge: base.titleLarge?.copyWith(
        color: tp,
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      titleMedium: base.titleMedium?.copyWith(
        color: tp,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: base.bodyLarge?.copyWith(color: tp),
      bodyMedium: base.bodyMedium?.copyWith(color: ts),
      bodySmall: base.bodySmall?.copyWith(color: tm),
      labelLarge: base.labelLarge?.copyWith(
        color: tp,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static InputDecorationTheme _buildInputTheme(Brightness b) {
    final inputBg = b == Brightness.dark ? surface : lSurface;
    final div = b == Brightness.dark ? divider : lDivider;
    final pr = b == Brightness.dark ? upload : lUpload;
    final tm = b == Brightness.dark ? textMuted : lTextMuted;
    final ts = b == Brightness.dark ? textSecondary : lTextSecondary;
    return InputDecorationTheme(
      filled: true,
      fillColor: inputBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: div),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: div),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: pr, width: 1.5),
      ),
      hintStyle: TextStyle(color: tm),
      labelStyle: TextStyle(color: ts),
    );
  }

  static ElevatedButtonThemeData _buildElevatedBtnTheme(Brightness b) {
    final pr = b == Brightness.dark ? upload : lPrimary;
    final fg = b == Brightness.dark ? background : Colors.white;
    return ElevatedButtonThemeData(
      style:
          ElevatedButton.styleFrom(
            backgroundColor: pr,
            foregroundColor: fg,
            disabledBackgroundColor: primDim(b).withValues(alpha: 0.55),
            disabledForegroundColor: textM(b),
            elevation: 0,
            shadowColor: Colors.transparent,
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ).copyWith(
            overlayColor: _stateLayer(b, fg),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return BorderSide(color: upl(b), width: 1.5);
              }
              return BorderSide.none;
            }),
          ),
    );
  }

  static OutlinedButtonThemeData _buildOutlinedBtnTheme(Brightness b) {
    final tp = b == Brightness.dark ? textPrimary : lTextPrimary;
    final div = b == Brightness.dark ? divider : lDivider;
    return OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            foregroundColor: tp,
            side: BorderSide(color: div),
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ).copyWith(
            overlayColor: _stateLayer(b, upl(b)),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return BorderSide(color: div.withValues(alpha: 0.55));
              }
              if (states.contains(WidgetState.focused)) {
                return BorderSide(color: upl(b), width: 1.5);
              }
              if (states.contains(WidgetState.hovered)) {
                return BorderSide(color: upl(b).withValues(alpha: 0.62));
              }
              return BorderSide(color: div);
            }),
          ),
    );
  }

  static TextButtonThemeData _buildTextBtnTheme(Brightness b) {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: upl(b),
        disabledForegroundColor: textM(b),
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ).copyWith(overlayColor: _stateLayer(b, upl(b))),
    );
  }

  static IconButtonThemeData _buildIconBtnTheme(Brightness b) {
    return IconButtonThemeData(
      style:
          IconButton.styleFrom(
            foregroundColor: textS(b),
            disabledForegroundColor: textM(b).withValues(alpha: 0.72),
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.padded,
            padding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm),
            ),
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return uplDim(b).withValues(alpha: 0.55);
              }
              if (states.contains(WidgetState.focused)) {
                return uplDim(b).withValues(alpha: 0.45);
              }
              if (states.contains(WidgetState.hovered)) {
                return surfL(b).withValues(alpha: 0.72);
              }
              return Colors.transparent;
            }),
            overlayColor: _stateLayer(b, upl(b)),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.focused)) {
                return BorderSide(color: upl(b).withValues(alpha: 0.68));
              }
              return BorderSide.none;
            }),
          ),
    );
  }

  static PopupMenuThemeData _buildPopupMenuTheme(Brightness b) {
    return PopupMenuThemeData(
      color: surf(b),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        side: BorderSide(color: surfBorder(b)),
      ),
      textStyle: TextStyle(
        color: textP(b),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? upl(b) : textP(b),
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        );
      }),
    );
  }

  static WidgetStateProperty<Color?> _stateLayer(Brightness b, Color color) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return null;
      if (states.contains(WidgetState.pressed)) {
        return color.withValues(alpha: b == Brightness.dark ? 0.18 : 0.14);
      }
      if (states.contains(WidgetState.focused)) {
        return color.withValues(alpha: b == Brightness.dark ? 0.16 : 0.12);
      }
      if (states.contains(WidgetState.hovered)) {
        return color.withValues(alpha: b == Brightness.dark ? 0.10 : 0.08);
      }
      return null;
    });
  }

  // Log font.
  static TextStyle logFont(Brightness b) => TextStyle(
    fontSize: 12.5,
    height: 1.6,
    color: b == Brightness.dark ? textSecondary : lTextSecondary,
  );

  /// Legacy static access kept for existing call sites.
  static TextStyle get logFontDark =>
      const TextStyle(fontSize: 12.5, height: 1.6, color: textSecondary);
}
