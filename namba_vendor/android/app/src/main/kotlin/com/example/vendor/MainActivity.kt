package com.example.vendor

import android.os.Build
import android.view.WindowManager
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
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
                val pkg = packageName
                var opened = false

                // MIUI (Xiaomi/POCO/Redmi) — open directly to Namba Vendor's permission page
                if (isMiui()) {
                    try {
                        val miuiIntent = Intent("miui.intent.action.APP_PERM_EDITOR")
                        miuiIntent.setClassName(
                            "com.miui.securitycenter",
                            "com.miui.permcenter.permissions.PermissionsEditorActivity"
                        )
                        miuiIntent.putExtra("extra_pkgname", pkg)
                        miuiIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(miuiIntent)
                        opened = true
                    } catch (e: Exception) { /* fallthrough */ }
                }

                // Standard Android: directly open this app's overlay settings page
                if (!opened && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$pkg")
                        )
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) { /* fallthrough */ }
                }

                // Final fallback: app info settings page
                if (!opened) {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = Uri.parse("package:$pkg")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    } catch (e: Exception) { }
                }

                result.success(opened)

            } else if (call.method == "openBatterySettings") {
                try {
                    val intent = Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName")
                    )
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                    } catch (e2: Exception) { }
                    result.success(false)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    // Detect MIUI (Xiaomi / POCO / Redmi phones)
    private fun isMiui(): Boolean {
        return try {
            val clazz = Class.forName("android.os.SystemProperties")
            val method = clazz.getMethod("get", String::class.java)
            val value = method.invoke(null, "ro.miui.ui.version.name") as String
            value.isNotEmpty()
        } catch (e: Exception) {
            false
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
