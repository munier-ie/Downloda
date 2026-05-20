package com.downloda.app

import android.content.Intent
import android.os.Bundle
import android.widget.Toast
import android.app.Activity
import android.os.Build

class ShareReceiverActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (sharedText != null) {
                // Show minimal feedback
                Toast.makeText(this, "Download started", Toast.LENGTH_SHORT).show()

                // Enqueue work to Flutter Workmanager
                try {
                    val serviceIntent = Intent(this, ShareForegroundService::class.java)
                    serviceIntent.putExtra("url", sharedText)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    Toast.makeText(this, "Failed to start background task", Toast.LENGTH_SHORT).show()
                }
            }
        }
        
        // Terminate instantly to avoid UI interruption
        finish()
    }
}
