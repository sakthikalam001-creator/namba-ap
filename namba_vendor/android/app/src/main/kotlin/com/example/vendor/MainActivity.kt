package com.example.vendor

import android.os.Build
import android.view.WindowManager
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.content.ComponentName
import android.net.Uri
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
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

                // 1. Direct AppDrawOverlaySettingsActivity with package data (Opens the exact [ON/OFF] switch page directly)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                            data = Uri.parse("package:$packageName")
                            component = ComponentName("com.android.settings", "com.android.settings.Settings\$AppDrawOverlaySettingsActivity")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {}
                }

                // 2. Direct official Android ACTION_MANAGE_OVERLAY_PERMISSION with package URI
                if (!opened && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {}
                }

                // 3. Alternative Uri format (Uri.fromParts)
                if (!opened && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.fromParts("package", packageName, null)
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {}
                }

                // 4. Action string format
                if (!opened) {
                    try {
                        val intent = Intent("android.settings.action.MANAGE_OVERLAY_PERMISSION").apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {}
                }

                // 5. Fallback to App Info page for Namba Vendor
                if (!opened) {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {}
                }

                result.success(opened)

            } else if (call.method == "openNotificationSettings") {
                var opened = false
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    }
                } catch (e: Exception) {}
                if (!opened) {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) {}
                }
                result.success(opened)

            } else if (call.method == "areNotificationsEnabled") {
                val enabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                result.success(enabled)

            } else if (call.method == "canDrawOverlays") {
                val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(this)
                } else {
                    true
                }
                result.success(canDraw)

            } else if (call.method == "openBatterySettings") {
                var opened = false

                // 1. Direct system Request Ignore Battery Optimizations intent (Shows system prompt: "Stop optimizing battery usage? [Allow]")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) { }
                }

                // 2. Direct Battery Optimization Settings List
                if (!opened && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) { }
                }

                // 3. OEM Background Managers (Xiaomi, Oppo, Vivo, Samsung, Realme)
                if (!opened) {
                    val oemIntents = arrayOf(
                        // MIUI Powerkeeper
                        Intent().setComponent(ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")).putExtra("package_name", packageName).putExtra("package_label", "Namba Vendor"),
                        // Oppo / Realme
                        Intent().setComponent(ComponentName("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaard.PowerConsumptionActivity")),
                        Intent().setComponent(ComponentName("com.coloros.oppoguardelf", "com.coloros.powermanager.fuelgaard.PowerUsageModelActivity")),
                        // Vivo
                        Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
                        Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
                        // Samsung
                        Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"))
                    )
                    for (oemIntent in oemIntents) {
                        try {
                            oemIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(oemIntent)
                            opened = true
                            break
                        } catch (e: Exception) { }
                    }
                }

                // 4. Fallback: Application Details Settings (App Info -> Battery)
                if (!opened) {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e: Exception) { }
                }

                result.success(opened)
            } else if (call.method == "openAppPermissionsSettings") {
                var opened = false
                // Try opening the specific "App permissions" page (Image 2) directly
                try {
                    val intent = Intent("android.intent.action.MANAGE_APP_PERMISSIONS").apply {
                        putExtra(Intent.EXTRA_PACKAGE_NAME, packageName)
                        putExtra("android.intent.extra.PACKAGE_NAME", packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    opened = true
                } catch (e: Exception) {
                    // Fallback to Application Details Settings
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.fromParts("package", packageName, null)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        opened = true
                    } catch (e2: Exception) { }
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
