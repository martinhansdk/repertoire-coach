import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TestWidgetWrapper {
  static Widget wrapWithMaterialApp(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    );
  }

  static Widget wrapWithScaffold(
    Widget child, {
    List<Override> overrides = const [],
  }) {
    return wrapWithMaterialApp(
      Scaffold(body: child),
      overrides: overrides,
    );
  }
}
