import 'dart:ui_web' as ui_web;

typedef WebViewFactory = Object Function(int);

void registerWebViewFactory(String viewType, WebViewFactory viewFactory) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return viewFactory(viewId);
  });
}
