package com.example.flutter_application_dashboard

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val channelName = "apk_metadata"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        if (call.method == "getApkMetadata") {
          val path = call.argument<String>("path")
          if (path.isNullOrEmpty()) {
            result.success(null)
            return@setMethodCallHandler
          }
          try {
            val pm = applicationContext.packageManager
            val info = pm.getPackageArchiveInfo(path, 0)
            if (info == null) {
              result.success(null)
              return@setMethodCallHandler
            }
            val appInfo = info.applicationInfo ?: run {
              result.success(null)
              return@setMethodCallHandler
            }
            appInfo.sourceDir = path
            appInfo.publicSourceDir = path
            val label = pm.getApplicationLabel(appInfo).toString()
            val version = info.versionName ?: ""
            val bundleId = info.packageName ?: ""
            val payload = mapOf(
              "title" to label,
              "version" to version,
              "bundleId" to bundleId
            )
            result.success(payload)
          } catch (e: Exception) {
            result.success(null)
          }
        } else {
          result.notImplemented()
        }
      }
  }
}
