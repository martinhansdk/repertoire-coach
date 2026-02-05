package com.repertoirecoach.repertoire_coach

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity: FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        // audio_service's AudioServicePlugin.getFlutterEngine() looks up
        // FlutterEngineCache under the key "audio_service_engine".  If it
        // doesn't find one it creates a SECOND engine, which causes the
        // "wrong engine detected" assertion and breaks AudioService.init().
        //
        // The delegate lifecycle order is:
        //   1. setUpFlutterEngine()  ← provideFlutterEngine() called here;
        //                               Flutter also calls registerWith() here
        //   2. attachToActivity()    ← onAttachedToActivity fires here
        //                               (audio_service checks the cache)
        //   3. platform channels
        //   4. configureFlutterEngine()
        //
        // configureFlutterEngine (step 4) is too late; the cache must be
        // populated before step 2.  provideFlutterEngine (step 1) is the
        // earliest hook.  Plugin registration is handled by Flutter in step 1,
        // so no configureFlutterEngine override is needed.
        val engine = FlutterEngine(context)
        FlutterEngineCache.getInstance().put("audio_service_engine", engine)
        return engine
    }
}
