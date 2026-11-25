package com.callmeste.planner

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal fun registerActaReleaseLinks(activity: Activity, messenger: BinaryMessenger) {
    val tagPattern = Regex("v[0-9]{1,4}\\.[0-9]{1,4}\\.[0-9]{1,4}-build\\.[1-9][0-9]{0,9}")

    @Suppress("DEPRECATION")
    fun canCheck(): Boolean {
        val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.packageManager.getInstallSourceInfo(activity.packageName).installingPackageName
        } else {
            activity.packageManager.getInstallerPackageName(activity.packageName)
        }
        return activity.packageName == "com.callmeste.planner" &&
            installer != "com.android.vending" &&
            Build.SUPPORTED_ABIS.contains("arm64-v8a")
    }

    MethodChannel(messenger, "planner/updates").setMethodCallHandler { call, result ->
        when (call.method) {
            "canCheck" -> result.success(canCheck())
            "openRelease" -> {
                val tag = call.arguments as? String
                if (tag == null || !tagPattern.matches(tag) || !canCheck()) {
                    result.success(false)
                } else {
                    val page = Uri.parse("https://github.com/Call-me-ste/Acta/releases/tag/$tag")
                    try {
                        activity.startActivity(Intent(Intent.ACTION_VIEW, page))
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        result.success(false)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
}
