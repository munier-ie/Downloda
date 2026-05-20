package com.downloda.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class ShareForegroundService : Service() {

    private var flutterEngine: FlutterEngine? = null
    private var methodChannel: MethodChannel? = null
    private val TAG = "ShareForegroundService"
    private var isEngineReady = false
    private val pendingUrls = mutableListOf<String>()

    companion object {
        const val CHANNEL_ID = "download_foreground_service_channel"
        const val NOTIF_ID = 1337
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification("Initializing download engine..."))
        
        Log.d(TAG, "Initializing Flutter Engine in Foreground Service")
        
        Handler(Looper.getMainLooper()).post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                if (!loader.initialized()) {
                    loader.startInitialization(applicationContext)
                }
                loader.ensureInitializationComplete(applicationContext, null)

                flutterEngine = FlutterEngine(applicationContext)
                
                // We use a specific entrypoint so it doesn't run the full UI
                val entrypoint = DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "shareDownloadBackgroundEntrypoint"
                )
                
                flutterEngine?.dartExecutor?.executeDartEntrypoint(entrypoint)

                val mediaScannerChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "com.downloda.app/media_scanner")
                mediaScannerChannel.setMethodCallHandler { call, result ->
                    if (call.method == "scanFile") {
                        val path = call.argument<String>("path")
                        if (path != null) {
                            android.media.MediaScannerConnection.scanFile(
                                applicationContext,
                                arrayOf(path),
                                null
                            ) { _, _ -> }
                            result.success(true)
                        } else {
                            result.error("INVALID_PATH", "Path was null", null)
                        }
                    } else {
                        result.notImplemented()
                    }
                }

                methodChannel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "com.downloda.app/share_download")
                methodChannel?.setMethodCallHandler { call, result ->
                    if (call.method == "stopService") {
                        Log.d(TAG, "Dart requested service stop")
                        stopSelf()
                        result.success(null)
                    } else if (call.method == "engineReady") {
                        isEngineReady = true
                        Log.d(TAG, "Dart engine reported ready. Processing ${pendingUrls.size} pending URLs.")
                        pendingUrls.forEach { url ->
                            methodChannel?.invokeMethod("startDownload", url)
                        }
                        pendingUrls.clear()
                        result.success(null)
                    } else {
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to initialize Flutter engine", e)
                stopSelf()
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val url = intent?.getStringExtra("url")
        Log.d(TAG, "Received URL to download: $url")
        
        if (url != null) {
            Handler(Looper.getMainLooper()).post {
                if (isEngineReady && methodChannel != null) {
                    methodChannel?.invokeMethod("startDownload", url)
                } else {
                    pendingUrls.add(url)
                }
            }
        } else if (pendingUrls.isEmpty() && isEngineReady) {
            // No URL and nothing pending, might have been restarted by system
            stopSelf()
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        Log.d(TAG, "Destroying ShareForegroundService")
        Handler(Looper.getMainLooper()).post {
            flutterEngine?.destroy()
            flutterEngine = null
            methodChannel = null
        }
        super.onDestroy()
    }

    private fun buildNotification(text: String): android.app.Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Downloda")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Background Downloads",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
