package com.example.vendor

import android.os.Build
import android.view.WindowManager
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.ComponentName
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.namba.vendor/app"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "moveTaskToBack") {
                val moved = moveTaskToBack(true)
                result.success(moved)

            } else if (call.method == "openOverlaySettings") {
                var opened = false

                // 1. Direct Namba Vendor App Info Page (Universal for ALL mobile brands!)
                // Opens Settings -> Apps -> Namba Vendor directly on Samsung, Vivo, Xiaomi, Oppo, Realme, etc.
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    intent.data = Uri.parse("package:$packageName")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    opened = true
                } catch (e: Exception) { }

                // 2. Try Vivo / iQOO (Funtouch OS) native permission manager
                if (!opened) {
                    try {
                        val intent = Intent()
                        intent.component = ComponentName(
                            "com.vivo.permissionmanager",
                            "com.vivo.permissionmanager.activity.SoftPermissionDetailActivity"
                        )
                        intent.putExtra("packagename", packageName)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) { }
                }

                // 3. Overlay Intent fallback
                if (!opened && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) { }
                }
                result.success(opened)

            } else if (call.method == "canDrawOverlays") {
                val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(this)
                } else {
                    true
                }
                result.success(canDraw)

            } else if (call.method == "openBatterySettings") {
                var opened = false

                // 1. Try MIUI Powerkeeper Background Settings page (Opens 'No restrictions' options directly)
                try {
                    val intent = Intent()
                    intent.component = ComponentName(
                        "com.miui.powerkeeper",
                        "com.miui.powerkeeper.ui.HiddenAppsConfigActivity"
                    )
                    intent.putExtra("package_name", packageName)
                    intent.putExtra("package_label", "Namba Vendor")
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    opened = true
                } catch (e: Exception) {
                    // Fallthrough to standard Android battery settings
                }

                // 2. Standard Android Request Ignore Battery Optimizations
                if (!opened) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName")
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {
                        try {
                            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            opened = true
                        } catch (e2: Exception) { }
                    }
                }

                result.success(opened)
            } else if (call.method == "isBatteryOptimizationsIgnored") {
                val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                val isIgnored = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    pm.isIgnoringBatteryOptimizations(packageName)
                } else {
                    true
                }
                result.success(isIgnored)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            keyguardManager.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
    }
}
