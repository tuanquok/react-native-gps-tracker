package com.gpstracker

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.modules.core.PermissionAwareActivity
import com.facebook.react.modules.core.PermissionListener

class GpsTrackerModule(private val reactContext: ReactApplicationContext) :
  NativeGpsTrackerSpec(reactContext),
  PermissionListener {

  override fun configure(config: ReadableMap) {
    GpsTrackerStore.saveConfig(reactContext, config)
  }

  override fun requestPermission() {
    val activity = reactContext.currentActivity as? PermissionAwareActivity ?: return

    if (!hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)) {
      activity.requestPermissions(
        foregroundPermissions().toTypedArray(),
        FOREGROUND_PERMISSION_REQUEST_CODE,
        this
      )
      return
    }

    requestBackgroundPermissionIfNeeded(activity)
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<String>,
    grantResults: IntArray
  ): Boolean {
    if (requestCode == FOREGROUND_PERMISSION_REQUEST_CODE) {
      val activity = reactContext.currentActivity as? PermissionAwareActivity ?: return true
      requestBackgroundPermissionIfNeeded(activity)
      return true
    }

    return requestCode == BACKGROUND_PERMISSION_REQUEST_CODE
  }

  override fun startTracking() {
    GpsTrackerStore.setTrackingEnabled(reactContext, true)
    GpsTrackerLocationService.start(reactContext)
  }

  override fun stopTracking() {
    GpsTrackerStore.setTrackingEnabled(reactContext, false)
    GpsTrackerLocationService.stop(reactContext)
  }

  override fun getCurrentLocation() {
    GpsTrackerLocationService.requestSingleLocation(reactContext)
  }

  override fun sync() {
  }

  private fun foregroundPermissions(): List<String> {
    val permissions = mutableListOf(
      Manifest.permission.ACCESS_COARSE_LOCATION,
      Manifest.permission.ACCESS_FINE_LOCATION
    )

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      permissions.add(Manifest.permission.POST_NOTIFICATIONS)
    }

    return permissions
  }

  private fun requestBackgroundPermissionIfNeeded(activity: PermissionAwareActivity) {
    if (
      Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
      !hasPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
    ) {
      activity.requestPermissions(
        arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
        BACKGROUND_PERMISSION_REQUEST_CODE,
        this
      )
    }
  }

  private fun hasPermission(permission: String): Boolean {
    return ContextCompat.checkSelfPermission(
      reactContext,
      permission
    ) == PackageManager.PERMISSION_GRANTED
  }

  companion object {
    const val NAME = NativeGpsTrackerSpec.NAME
    private const val FOREGROUND_PERMISSION_REQUEST_CODE = 1001
    private const val BACKGROUND_PERMISSION_REQUEST_CODE = 1002
  }
}
