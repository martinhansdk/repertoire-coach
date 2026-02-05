package com.repertoirecoach.repertoire_coach

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity: FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        // audio_service's AudioServicePlugin.getFlutterEngine() looks up
        // FlutterEngineCache under the key "audio_service_engine".  If it
        // doesn't find one it creates a SECOND engine, which causes the
        // "wrong engine detected" assertion and breaks AudioService.init().
        //
        // The delegate lifecycle order is:
        //   1. setUpFlutterEngine()  ← provideFlutterEngine() is called here
        //   2. attachToActivity()    ← onAttachedToActivity fires here (audio_service checks cache)
        //   3. platform channels
        //   4. configureFlutterEngine()
        //
        // configureFlutterEngine (step 4) is too late; the cache must be populated
        // before step 2.  provideFlutterEngine (step 1) is the earliest hook.
        val engine = FlutterEngine(context)
        FlutterEngineCache.getInstance().put("audio_service_engine", engine)
        return engine
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // When provideFlutterEngine() returns a non-null engine,
        // isFlutterEngineFromHost() is true and the default
        // configureFlutterEngine skips plugin registration.
        // Register plugins explicitly so the app works normally.
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
