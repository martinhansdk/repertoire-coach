/// Platform-specific database connection
///
/// This file exports the correct database connection implementation
/// based on the platform (web vs native)
library;

export 'database_connection_native.dart'
    if (dart.library.html) 'database_connection_web.dart';
