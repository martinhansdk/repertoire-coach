typedef WebViewFactory = Object Function(int);

void registerWebViewFactory(String viewType, WebViewFactory viewFactory) {
  // Non-web: no-op.
}
