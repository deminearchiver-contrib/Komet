import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:gwid/widgets/raw_material_app.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'dart:io';
import 'dart:math';
import 'screens/home_screen.dart';
import 'screens/phone_entry_screen.dart';
import 'utils/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:gwid/api/api_service.dart';
import 'connection_lifecycle_manager.dart';
import 'services/cache_service.dart';
import 'services/avatar_cache_service.dart';
import 'services/chat_cache_service.dart';
import 'services/contact_local_names_service.dart';
import 'services/account_manager.dart';
import 'services/music_player_service.dart';
import 'services/whitelist_service.dart';
import 'services/notification_service.dart';
import 'services/message_queue_service.dart';
import 'plugins/plugin_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'utils/device_presets.dart';

import 'package:libmonet/material_color_utilities.dart' as mcu;

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

extension DynamicSchemeExtension on mcu.DynamicScheme {
  ColorScheme toColorScheme() => ColorScheme(
    brightness: isDark ? Brightness.dark : Brightness.light,
    // ignore: deprecated_member_use
    background: Color(background),
    // ignore: deprecated_member_use
    onBackground: Color(onBackground),
    surface: Color(surface),
    surfaceDim: Color(surfaceDim),
    surfaceBright: Color(surfaceBright),
    surfaceContainerLowest: Color(surfaceContainerLowest),
    surfaceContainerLow: Color(surfaceContainerLow),
    surfaceContainer: Color(surfaceContainer),
    surfaceContainerHigh: Color(surfaceContainerHigh),
    surfaceContainerHighest: Color(surfaceContainerHighest),
    onSurface: Color(onSurface),
    // ignore: deprecated_member_use
    surfaceVariant: Color(surfaceVariant),
    onSurfaceVariant: Color(onSurfaceVariant),
    outline: Color(outline),
    outlineVariant: Color(outlineVariant),
    inverseSurface: Color(inverseSurface),
    onInverseSurface: Color(inverseOnSurface),
    shadow: Color(shadow),
    scrim: Color(scrim),
    surfaceTint: Color(surfaceTint),
    primary: Color(primary),
    onPrimary: Color(onPrimary),
    primaryContainer: Color(primaryContainer),
    onPrimaryContainer: Color(onPrimaryContainer),
    primaryFixed: Color(primaryFixed),
    primaryFixedDim: Color(primaryFixedDim),
    onPrimaryFixed: Color(onPrimaryFixed),
    onPrimaryFixedVariant: Color(onPrimaryFixedVariant),
    inversePrimary: Color(inversePrimary),
    secondary: Color(secondary),
    onSecondary: Color(onSecondary),
    secondaryContainer: Color(secondaryContainer),
    onSecondaryContainer: Color(onSecondaryContainer),
    secondaryFixed: Color(secondaryFixed),
    secondaryFixedDim: Color(secondaryFixedDim),
    onSecondaryFixed: Color(onSecondaryFixed),
    onSecondaryFixedVariant: Color(onSecondaryFixedVariant),
    tertiary: Color(tertiary),
    onTertiary: Color(onTertiary),
    tertiaryContainer: Color(tertiaryContainer),
    onTertiaryContainer: Color(onTertiaryContainer),
    tertiaryFixed: Color(tertiaryFixed),
    tertiaryFixedDim: Color(tertiaryFixedDim),
    onTertiaryFixed: Color(onTertiaryFixed),
    onTertiaryFixedVariant: Color(onTertiaryFixedVariant),
    error: Color(error),
    onError: Color(onError),
    errorContainer: Color(errorContainer),
    onErrorContainer: Color(onErrorContainer),
  );
}

Future<void> _generateInitialAndroidSpoof() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final isSpoofingEnabled = prefs.getBool('spoofing_enabled') ?? false;

    if (isSpoofingEnabled) {
      print('Спуф уже настроен, генерация не требуется');
      return;
    }

    print('Генерируем автоматический спуф для Android...');

    final androidPresets = devicePresets
        .where((p) => p.deviceType == 'ANDROID')
        .toList();

    if (androidPresets.isEmpty) {
      print('Не найдены пресеты для Android');
      return;
    }

    final random = Random();
    final preset = androidPresets[random.nextInt(androidPresets.length)];

    const uuid = Uuid();
    final deviceId = uuid.v4();

    String timezone;
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      timezone = timezoneInfo.identifier;
    } catch (_) {
      timezone = 'Europe/Moscow';
    }

    final locale = Platform.localeName.split('_').first;

    await prefs.setBool('spoofing_enabled', true);
    await prefs.setBool('anonymity_enabled', true);
    await prefs.setString('spoof_useragent', preset.userAgent);
    await prefs.setString('spoof_devicename', preset.deviceName);
    await prefs.setString('spoof_osversion', preset.osVersion);
    await prefs.setString('spoof_screen', preset.screen);
    await prefs.setString('spoof_timezone', timezone);
    await prefs.setString('spoof_locale', locale);
    await prefs.setString('spoof_deviceid', deviceId);
    await prefs.setString('spoof_devicetype', 'ANDROID');
    await prefs.setString('spoof_appversion', '25.21.3');

    print('Спуф для Android успешно сгенерирован:');
    print('  - Устройство: ${preset.deviceName}');
    print('  - ОС: ${preset.osVersion}');
    print('  - Device ID: $deviceId');
    print('  - Часовой пояс: $timezone');
    print('  - Локаль: $locale');
  } catch (e) {
    print('Ошибка при генерации спуфа: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  print("Генерируем спуф для Android при первом запуске...");
  await _generateInitialAndroidSpoof();
  print("Проверка и генерация спуфа завершена");

  print("Инициализируем сервисы кеширования...");
  await CacheService().initialize();
  await AvatarCacheService().initialize();
  await ChatCacheService().initialize();
  await ContactLocalNamesService().initialize();
  await MessageQueueService().initialize();
  print("Сервисы кеширования инициализированы");

  print("Инициализируем AccountManager...");
  await AccountManager().initialize();
  await AccountManager().migrateOldAccount();
  print("AccountManager инициализирован");

  print("Инициализируем MusicPlayerService...");
  await MusicPlayerService().initialize();
  print("MusicPlayerService инициализирован");

  print("Инициализируем PluginService...");
  await PluginService().initialize();
  print("PluginService инициализирован");

  print("Инициализируем WhitelistService...");
  await WhitelistService().loadWhitelist();
  print("WhitelistService инициализирован");

  print("Инициализируем NotificationService...");
  await NotificationService().initialize();
  NotificationService().setNavigatorKey(navigatorKey);
  print("NotificationService инициализирован");

  if (Platform.isAndroid) {
    print("Инициализируем фоновый сервис для Android...");
    await initializeBackgroundService();
    print("Фоновый сервис инициализирован");
  }

  print("Очищаем сессионные значения...");
  await ApiService.clearSessionValues();
  print("Сессионные значения очищены");

  final hasToken = await ApiService.instance.hasToken();
  print("При запуске приложения токен ${hasToken ? 'найден' : 'не найден'}");

  if (hasToken) {
    await WhitelistService().validateCurrentUserIfNeeded();

    if (await ApiService.instance.hasToken()) {
      print("Инициируем подключение к WebSocket при запуске...");
      ApiService.instance.connect();
    } else {
      print("Токен удалён после проверки вайтлиста, автологин отключён");
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => MusicPlayerService()),
      ],
      child: ConnectionLifecycleManager(child: MyApp(hasToken: hasToken)),
    ),
  );
}

enum CustomCheckboxVariant { phone, watch }

enum CustomSwitchVariant { phone, watch, nowInAndroid }

abstract final class LegacyThemeFactory {
  static CheckboxThemeData createCheckboxTheme({
    required ColorScheme colorScheme,
    required CustomCheckboxVariant variant,
  }) {
    final unselectedContainerColor = switch (variant) {
      .phone => Colors.transparent,
      .watch => colorScheme.surfaceContainer,
    };

    final selectedContainerColor = switch (variant) {
      .phone => colorScheme.primary,
      .watch => colorScheme.onPrimaryContainer,
    };

    final unselectedOutlineColor = switch (variant) {
      .phone => colorScheme.onSurfaceVariant,
      .watch => colorScheme.outline,
    };

    final selectedOutlineColor = switch (variant) {
      .phone => colorScheme.primary,
      .watch => colorScheme.onPrimaryContainer,
    };

    return CheckboxThemeData(
      splashRadius: 40.0 / 2.0,
      visualDensity: .standard,
    );
  }

  static SwitchThemeData createSwitchTheme({
    required ColorScheme colorScheme,
    required CustomSwitchVariant variant,
  }) {
    final unselectedContainerColor = switch (variant) {
      .phone => colorScheme.surfaceContainerHighest,
      .watch => colorScheme.surfaceContainer,
      .nowInAndroid => colorScheme.onSurfaceVariant,
    };
    final selectedContainerColor = switch (variant) {
      .phone => colorScheme.primary,
      .watch => colorScheme.onPrimaryContainer,
      .nowInAndroid => colorScheme.onPrimaryContainer,
    };

    final unselectedOutlineColor = switch (variant) {
      .phone => colorScheme.outline,
      .watch => colorScheme.outline,
      .nowInAndroid => colorScheme.onSurfaceVariant,
    };
    final selectedOutlineColor = switch (variant) {
      .phone => colorScheme.primary,
      .watch => colorScheme.onPrimaryContainer,
      .nowInAndroid => colorScheme.onPrimaryContainer,
    };

    final unselectedHandleColor = switch (variant) {
      .phone => colorScheme.outline,
      .watch => colorScheme.outline,
      .nowInAndroid => colorScheme.surfaceContainerHighest,
    };
    final selectedHandleColor = switch (variant) {
      .phone => colorScheme.onPrimary,
      .watch => colorScheme.primaryContainer,
      .nowInAndroid => colorScheme.primaryContainer,
    };

    final unselectedIconColor = switch (variant) {
      .phone => colorScheme.surfaceContainerHighest,
      .watch => colorScheme.surfaceContainer,
      .nowInAndroid => colorScheme.onSurfaceVariant,
    };
    final selectedIconColor = switch (variant) {
      .phone => colorScheme.primary,
      .watch => colorScheme.onPrimaryContainer,
      .nowInAndroid => colorScheme.onPrimaryContainer,
    };

    return SwitchThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashRadius: 40.0 / 2.0,
      trackColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? selectedContainerColor
            : unselectedContainerColor,
      ),
      trackOutlineWidth: const WidgetStatePropertyAll(2.0),
      trackOutlineColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? selectedOutlineColor
            : unselectedOutlineColor,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? selectedHandleColor
            : unselectedHandleColor,
      ),
      // overlayColor: WidgetStateProperty.resolveWith((states) {
      //   final stateLayerColor = states.contains(WidgetState.selected)
      //       ? colorScheme.primaryContainer
      //       : colorScheme.onSurfaceVariant;
      //   final double stateLayerOpacity;
      //   if (states.contains(WidgetState.disabled)) {
      //     stateLayerOpacity = 0.0;
      //   } else if (states.contains(WidgetState.pressed)) {
      //     stateLayerOpacity = 0.10;
      //   } else if (states.contains(WidgetState.focused)) {
      //     stateLayerOpacity = 0.1;
      //   } else if (states.contains(WidgetState.hovered)) {
      //     stateLayerOpacity = 0.08;
      //   } else {
      //     stateLayerOpacity = 0.0;
      //   }
      //   return stateLayerOpacity > 0.0
      //       ? stateLayerColor.withValues(alpha: stateLayerOpacity)
      //       : stateLayerColor.withAlpha(0);
      // }),
      thumbIcon: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return Icon(
          isSelected ? Symbols.check_rounded : Symbols.close_rounded,
          applyTextScaling: false,
          fill: 1.0,
          weight: 400.0,
          opticalSize: 24.0,
          size: 16.0,
          color: isSelected ? selectedIconColor : unselectedIconColor,
        );
      }),
    );
  }
}

class MyApp extends StatelessWidget {
  final bool hasToken;

  const MyApp({super.key, required this.hasToken});

  ThemeData _createTheme({
    required ThemeProvider themeProvider,
    required ColorScheme colorScheme,
  }) {
    final isWatch = themeProvider.appTheme == .black;
    return ThemeData(
      colorScheme: colorScheme,
      visualDensity: .standard,
      shadowColor: themeProvider.optimization ? Colors.transparent : null,
      splashFactory: themeProvider.optimization
          ? NoSplash.splashFactory
          : InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        toolbarHeight: 64.0,
        // Убираем устаревший surfaceTint и оставляем только surfaceContainer
        // при состоянии scrolled under
        elevation: 0.0,
        scrolledUnderElevation: 0.0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // Стиль текста заголовка
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: .w600,
          color: colorScheme.onSurface,
        ),
      ),
      checkboxTheme: LegacyThemeFactory.createCheckboxTheme(
        colorScheme: colorScheme,
        variant: isWatch ? .watch : .phone,
      ),
      switchTheme: LegacyThemeFactory.createSwitchTheme(
        colorScheme: colorScheme,
        variant: isWatch ? .watch : .phone,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        height: 64.0,
        elevation: 0.0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      pageTransitionsTheme: themeProvider.optimization
          ? const PageTransitionsTheme(
              builders: {
                .android: FadeUpwardsPageTransitionsBuilder(),
                .fuchsia: FadeUpwardsPageTransitionsBuilder(),
                .iOS: FadeUpwardsPageTransitionsBuilder(),
                .linux: FadeUpwardsPageTransitionsBuilder(),
                .macOS: FadeUpwardsPageTransitionsBuilder(),
                .windows: FadeUpwardsPageTransitionsBuilder(),
              },
            )
          : const PageTransitionsTheme(
              builders: {
                .android: FadeForwardsPageTransitionsBuilder(),
                .fuchsia: FadeForwardsPageTransitionsBuilder(),
                .iOS: CupertinoPageTransitionsBuilder(),
                .linux: FadeForwardsPageTransitionsBuilder(),
                .macOS: CupertinoPageTransitionsBuilder(),
                .windows: FadeForwardsPageTransitionsBuilder(),
              },
            ),
    );
  }

  Widget _buildLegacyTheme(BuildContext context, Widget child) {
    final themeProvider = context.watch<ThemeProvider>();
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final Brightness brightness = switch (themeProvider.themeMode) {
          .system => MediaQuery.platformBrightnessOf(context),
          .light => .light,
          .dark => .dark,
        };

        final useMaterialYou =
            themeProvider.appTheme == .system &&
            lightDynamic != null &&
            darkDynamic != null;

        final sourceColor = useMaterialYou
            ? lightDynamic.primary
            : themeProvider.accentColor;

        final sourceColorHct = mcu.Hct.fromInt(sourceColor.toARGB32());

        final colorScheme = useMaterialYou
            ? switch (brightness) {
                .light => lightDynamic,
                .dark => darkDynamic,
              }
            : mcu.DynamicScheme.fromPalettesOrKeyColors(
                isDark: brightness == .dark,
                sourceColorHct: sourceColorHct,
                contrastLevel: 0.0,
                variant: .tonalSpot,
                specVersion: .spec2025,
                platform: themeProvider.appTheme == .black ? .watch : .phone,
              ).toColorScheme();

        var theme = _createTheme(
          themeProvider: themeProvider,
          colorScheme: colorScheme,
        );

        if (themeProvider.appTheme == .black) {
          theme = theme.copyWith(
            scaffoldBackgroundColor: Colors.black,
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Colors.black,
              indicatorColor: sourceColor.withValues(alpha: 0.4),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return TextStyle(
                    color: sourceColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  );
                }
                return const TextStyle(color: Colors.grey, fontSize: 12);
              }),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return IconThemeData(color: sourceColor);
                }
                return const IconThemeData(color: Colors.grey);
              }),
            ),
          );
        }
        return Theme(data: theme, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    final padding = MediaQuery.paddingOf(context);

    if (themeProvider.optimization) {
      timeDilation = 0.001;
    } else {
      timeDilation = 1.0;
    }

    final app = RawMaterialApp(
      title: 'Komet',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ru'), Locale('en')],
      locale: const Locale('ru'),
      navigatorKey: navigatorKey,
      builder: (context, child) {
        final showHud =
            themeProvider.debugShowPerformanceOverlay ||
            themeProvider.showFpsOverlay;
        return SizedBox.expand(
          child: Stack(
            children: [
              if (child != null) child,
              if (showHud)
                Positioned(
                  top: 64.0 + 48.0 + 16.0,
                  right: 16.0,
                  child: Padding(
                    padding: padding,
                    child: IgnorePointer(child: _MiniFpsHud()),
                  ),
                ),
            ],
          ),
        );
      },
      home: hasToken ? const HomeScreen() : const PhoneEntryScreen(),
    );

    return Builder(builder: (context) => _buildLegacyTheme(context, app));
  }
}

class _MiniFpsHud extends StatefulWidget {
  const _MiniFpsHud();

  @override
  State<_MiniFpsHud> createState() => _MiniFpsHudState();
}

class _MiniFpsHudState extends State<_MiniFpsHud> {
  final List<FrameTiming> _timings = <FrameTiming>[];
  static const int _sampleSize = 60;
  double _fps = 0.0;
  double _avgMs = 0.0;

  void _onTimings(List<FrameTiming> timings) {
    _timings.addAll(timings);
    if (_timings.length > _sampleSize) {
      _timings.removeRange(0, _timings.length - _sampleSize);
    }
    if (_timings.isEmpty) return;
    final double avg =
        _timings
            .map((t) => (t.totalSpan.inMicroseconds) / 1000.0)
            .fold(0.0, (a, b) => a + b) /
        _timings.length;
    if (!mounted) return;
    setState(() {
      _avgMs = avg;
      _fps = avg > 0 ? (1000.0 / avg) : 0.0;
    });
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);
    return Material(
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12.0)),
      ),
      color: themeProvider.optimization
          ? colorScheme.inverseSurface
          : colorScheme.surfaceContainer,
      elevation: themeProvider.optimization
          ? 0.0
          // md.sys.elevation.level3
          : 6.0,
      shadowColor: colorScheme.shadow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: DefaultTextStyle(
          textAlign: TextAlign.end,
          style: textTheme.labelSmall!.copyWith(
            fontFamily: "monospace",
            fontWeight: FontWeight.w600,
            fontVariations: [FontVariation.weight(600.0)],
            fontFeatures: const [FontFeature.tabularFigures()],
            color: themeProvider.optimization
                ? colorScheme.onInverseSurface
                : colorScheme.onSurfaceVariant,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_fps.toStringAsFixed(0)} fps'),
              const SizedBox(height: 4.0),
              Text('${_avgMs.toStringAsFixed(1)} ms'),
            ],
          ),
        ),
      ),
    );
  }
}
