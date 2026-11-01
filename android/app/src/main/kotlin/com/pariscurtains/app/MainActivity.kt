package com.pariscurtains.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (مش FlutterActivity) لأن بصمة local_auth محتاجاها.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // قناة إشعارات الأجندة (لازم تكون موجودة عشان الإشعار يظهر بصوت وفوق الشاشة)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "agenda",
                "تنبيهات الأجندة",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "تنبيه بتركيبات النهاردة وبكرة"
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }
}
