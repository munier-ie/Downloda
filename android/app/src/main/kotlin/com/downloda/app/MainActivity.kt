package com.downloda.app

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.downloda.app/media_scanner"
    private val ICON_CHANNEL = "com.downloda.app/app_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        scanFile(path)
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "Path was null", null)
                    }
                }
                "getVideoThumbnail" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        val bytes = getVideoThumbnail(path)
                        if (bytes != null) {
                            result.success(bytes)
                        } else {
                            result.error("THUMBNAIL_FAILED", "Could not generate thumbnail", null)
                        }
                    } else {
                        result.error("INVALID_PATH", "Path was null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "changeIcon" -> {
                    val mode = call.argument<String>("mode") ?: "light"
                    changeAppIcon(applicationContext, mode)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun changeAppIcon(context: Context, mode: String) {
        val pm = context.packageManager
        val lightAlias = ComponentName(context, "com.downloda.app.MainActivityLight")
        val darkAlias = ComponentName(context, "com.downloda.app.MainActivityDark")

        try {
            if (mode == "dark") {
                // Enable Dark Icon
                pm.setComponentEnabledSetting(
                    darkAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                // Disable Light Icon
                pm.setComponentEnabledSetting(
                    lightAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            } else {
                // Enable Light Icon
                pm.setComponentEnabledSetting(
                    lightAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                // Disable Dark Icon
                pm.setComponentEnabledSetting(
                    darkAlias,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun scanFile(path: String) {
        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(path),
            null
        ) { scanPath, uri ->
            // Scan completed
        }
    }

    private fun getVideoThumbnail(path: String): ByteArray? {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            // Grab a frame at 1 second mark, or fallback to first frame
            val bitmap = retriever.getFrameAtTime(1000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
                ?: retriever.frameAtTime
            
            if (bitmap != null) {
                val stream = ByteArrayOutputStream()
                // Compress to JPEG with 70% quality for efficiency
                bitmap.compress(Bitmap.CompressFormat.JPEG, 70, stream)
                return stream.toByteArray()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return null
    }
}
