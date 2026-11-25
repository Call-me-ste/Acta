package com.callmeste.planner

import android.content.Intent
import android.os.Build
import android.view.Surface
import android.view.SurfaceHolder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * L'Activity dell'app, con una cosa in piu': **chiede al display la frequenza
 * massima** che sa fare.
 *
 * Perche' serve: il motore di Flutter non chiama `Surface.setFrameRate`, quindi
 * su molti telefoni a 120 Hz le app Flutter restano a **60** (e' il caso
 * documentato in flutter/flutter#160952 e #35162). Il risultato e' un'app che
 * "sembra sempre al limite": non perche' faccia troppo lavoro, ma perche' ha la
 * meta' dei fotogrammi che potrebbe avere.
 *
 * Non serve nessun permesso e non si forza niente: si **chiede** il massimo
 * della modalita' corrente (stessa risoluzione, refresh piu' alto). Il sistema
 * puo' dire di no per risparmio energetico, temperatura o impostazioni
 * dell'utente — ed e' giusto cosi'.
 */
class MainActivity : FlutterActivity() {

    private val copiaPicker = BackupFilePicker(this)
    private val sharedFiles = PlannerSharedFiles(this)
    private val driveAuthorization = PlannerDriveAuthorization(this)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        copiaPicker.registra(flutterEngine.dartExecutor.binaryMessenger)
        registerActaReleaseLinks(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "planner/document_scanner")
            .setMethodCallHandler { call, result ->
                if (call.method == "capturePdf") {
                    val paths = call.argument<List<String>>("paths")
                        ?: listOfNotNull(call.argument<String>("path"))
                    captureScanPdf(this, paths, result)
                } else if (call.method == "preparePhoto") {
                    prepareScanPhoto(this, null, result, call.argument<String>("path"))
                } else {
                    result.notImplemented()
                }
            }
        sharedFiles.register(flutterEngine.dartExecutor.binaryMessenger)
        driveAuthorization.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sharedFiles.accept(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        copiaPicker.consegna(requestCode, resultCode, data)
        sharedFiles.complete(requestCode, resultCode, data)
        driveAuthorization.complete(requestCode, resultCode, data)
    }

    override fun onFlutterSurfaceViewCreated(flutterSurfaceView: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(flutterSurfaceView)
        flutterSurfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                // Una volta per superficie: cambiare frequenza costa un fotogramma,
                // quindi non si fa a ogni frame.
                requestMaxFrameRate(holder)
            }

            override fun surfaceChanged(
                holder: SurfaceHolder,
                format: Int,
                width: Int,
                height: Int,
            ) = Unit

            override fun surfaceDestroyed(holder: SurfaceHolder) = Unit
        })
    }

    private fun requestMaxFrameRate(holder: SurfaceHolder) {
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display ?: return
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay ?: return
        }

        val current = display.mode ?: return
        // Si sceglie la frequenza piu' alta **a pari risoluzione**: chiedere un
        // altro formato di schermo farebbe cambiare risoluzione, che e' un'altra
        // cosa e si vede.
        val maxHz = display.supportedModes
            .filter {
                it.physicalWidth == current.physicalWidth &&
                    it.physicalHeight == current.physicalHeight
            }
            .maxOfOrNull { it.refreshRate }
            ?: display.refreshRate

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> holder.surface.setFrameRate(
                maxHz,
                Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS,
            )

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> holder.surface.setFrameRate(
                maxHz,
                Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
            )

            else -> window.attributes = window.attributes.apply {
                // Non insieme a `setFrameRate`: su una superficie che lo chiama,
                // Android ignora questo valore.
                preferredDisplayModeId = 0
                preferredRefreshRate = maxHz
            }
        }
    }
}
