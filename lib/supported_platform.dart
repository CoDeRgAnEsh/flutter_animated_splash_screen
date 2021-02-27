/// ## If the current platform is supported, load dart.io.
///
/// Creating images necessary for the splash screens requires the io.dart package, which
/// unfortunately does not have support for JS.  Because pub.dev docks pub points for
/// packages not being cross-platform, it is necessary to use
/// [conditional imports](https://dart.dev/guides/libraries/create-library-packages#conditionally-importing-and-exporting-library-files)
/// to avoid losing pub points.  This library is included when the package is loaded on
/// a supported platform, loads dart.io and the rest of the package.
library animated_native_splash_supported_platform;

import 'dart:io';

import 'package:yaml/yaml.dart';

part 'android.dart';
part 'constants.dart';
part 'exceptions.dart';
part 'templates.dart';

/// Function that will be called on supported platforms to create the splash screens.
Future<void> tryCreateSplash() async {
  var config = await _getConfig();
  await tryCreateSplashByConfig(config);
}

/// Function that will be called on supported platforms to remove the splash screens.
Future<void> tryRemoveSplash() async {
  print('Restoring animated\'s default white native splash screen...');
  await tryCreateSplashByConfig({'color': '#ffffff'});
}

/// Function that will be called on supported platforms to create the splash screen based on a config argument.
Future<void> tryCreateSplashByConfig(Map<String, dynamic> config) async {
  String jsonFile = config['jsonFile'] ?? '';
  var color = _parseColor(config['color']);
  var darkColor = _parseColor(config['color_dark']);

  if (!config.containsKey('android') || config['android']) {
    await _createAndroidSplash(
      jsonPath: jsonFile,
      color: color,
      darkColor: darkColor,
    );
  }
}

String _parseColor(var color) {
  if (color is int) color = color.toString().padLeft(6, '0');

  if (color is String) {
    color = color.replaceAll('#', '').replaceAll(' ', '');
    if (color.length == 6) return color;
  }
  if (color == null) return '';

  throw Exception('Invalid color value');
}

/// Get config from `pubspec.yaml` or `animated_native_splash.yaml`
Map<String, dynamic> _getConfig() {
  // if `animated_native_splash.yaml` exists use it as config file, otherwise use `pubspec.yaml`
  var filePath = (FileSystemEntity.typeSync('animated_native_splash.yaml') !=
          FileSystemEntityType.notFound)
      ? 'animated_native_splash.yaml'
      : 'pubspec.yaml';

  final file = File(filePath);
  final yamlString = file.readAsStringSync();
  final Map yamlMap = loadYaml(yamlString);

  if (!(yamlMap['animated_native_splash'] is Map)) {
    stderr.writeln(_NoConfigFoundException(
        'Your `$filePath` file does not contain a `animated_native_splash` section.'));
    exit(1);
  }

  // yamlMap has the type YamlMap, which has several unwanted side effects
  final config = <String, dynamic>{};
  for (MapEntry<dynamic, dynamic> entry
      in yamlMap['animated_native_splash'].entries) {
    if (entry.value is YamlList) {
      var list = <String>[];
      (entry.value as YamlList).forEach((dynamic value) {
        if (value is String) {
          list.add(value);
        }
      });
      config[entry.key] = list;
    } else {
      config[entry.key] = entry.value;
    }
  }

  if (!config.containsKey('color')) {
    stderr.writeln(_InvalidConfigException(
        'Your `animated_native_splash` section does not contain a `color`.'));
    exit(1);
  }

  if (config.containsKey('image_dark') && !config.containsKey('color_dark')) {
    stderr.writeln(_InvalidConfigException(
        'Your `animated_native_splash` section contains `image_dark` but does not contain a `color_dark`.'));
    exit(1);
  }

  return config;
}
