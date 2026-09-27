import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

final appLogger = Logger(
  level: kReleaseMode ? Level.warning: Level.debug,
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  )
);