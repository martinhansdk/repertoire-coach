package com.repertoirecoach.repertoire_coach

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // audio_service's AudioServicePlugin.getFlutterEngine() looks up
        // FlutterEngineCache under the key "audio_service_engine".  If it
        // doesn't find one it creates a SECOND engine, which causes the
        // "wrong engine detected" assertion and breaks AudioService.init().
        // Caching the main engine here (after creation, before activity
        // attachment) makes both the app and the background AudioService
        // share the same FlutterEngine.
        FlutterEngineCache.getInstance().put("audio_service_engine", flutterEngine)
    }
}
