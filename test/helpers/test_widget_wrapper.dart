import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TestWidgetWrapper {
  static Widget wrapWithMaterialApp(
    Widget child, {
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      // ignore: argument_type_not_assignable
      overrides: overrides.cast(),
      child: MaterialApp(home: child),
    );
  }

  static Widget wrapWithScaffold(
    Widget child, {
    List<dynamic> overrides = const [],
  }) {
    return wrapWithMaterialApp(
      Scaffold(body: child),
      overrides: overrides,
    );
  }
}
