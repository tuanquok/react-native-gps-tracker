package com.gpstracker

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class GpsTrackerLocationService : Service(), LocationListener {
  private val locationManager by lazy {
    getSystemService(Context.LOCATION_SERVICE) as LocationManager
  }

  override fun onCreate() {
    super.onCreate()
    createNotificationChannel()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (!GpsTrackerStore.isTrackingEnabled(this)) {
      stopSelf()
      return START_NOT_STICKY
    }

    startAsForeground()
    startLocationUpdates()
    return START_STICKY
  }

  override fun onDestroy() {
    locationManager.removeUpdates(this)
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onLocationChanged(location: Location) {
    GpsTrackerActionRunner.run(this, location)
  }

  @Deprecated("Deprecated in Java")
  override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

  override fun onProviderEnabled(provider: String) = Unit

  override fun onProviderDisabled(provider: String) = Unit

  @SuppressLint("MissingPermission")
  private fun startLocationUpdates() {
    if (!hasFineLocationPermission(this)) {
      stopSelf()
      return
    }

    val config = GpsTrackerStore.loadConfig(this)
    val androidConfig = config?.optJSONObject("android")
    val intervalMs = androidConfig?.optLong("intervalMs", LOCATION_INTERVAL_MS)
      ?: LOCATION_INTERVAL_MS
    val distanceFilterMeters =
      androidConfig?.optDouble("distanceFilterMeters", LOCATION_DISTANCE_METERS.toDouble())
        ?.toFloat()
        ?: LOCATION_DISTANCE_METERS
    val providers = resolveProviders(androidConfig)

    for (provider in providers) {
      if (!locationManager.isProviderEnabled(provider)) {
        continue
      }

      locationManager.requestLocationUpdates(
        provider,
        intervalMs,
        distanceFilterMeters,
        this
      )

      if (androidConfig?.optBoolean("writeLastKnownLocationOnStart", false) == true) {
        locationManager.getLastKnownLocation(provider)?.let {
          GpsTrackerActionRunner.run(this, it)
        }
      }
    }
  }

  private fun resolveProviders(androidConfig: org.json.JSONObject?): List<String> {
    val configuredProviders = androidConfig?.optJSONArray("providers") ?: return listOf(
      LocationManager.GPS_PROVIDER
    )

    val providers = mutableListOf<String>()
    for (index in 0 until configuredProviders.length()) {
      when (configuredProviders.optString(index)) {
        "gps" -> providers.add(LocationManager.GPS_PROVIDER)
        "network" -> providers.add(LocationManager.NETWORK_PROVIDER)
      }
    }

    return providers.ifEmpty { listOf(LocationManager.GPS_PROVIDER) }
  }

  private fun startAsForeground() {
    val notification = createNotification()

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      startForeground(
        NOTIFICATION_ID,
        notification,
        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
      )
      return
    }

    startForeground(NOTIFICATION_ID, notification)
  }

  private fun createNotification(): Notification {
    return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
      .setContentTitle("GPS tracking is running")
      .setContentText("Location updates are being tracked in the background.")
      .setSmallIcon(android.R.drawable.ic_menu_mylocation)
      .setOngoing(true)
      .build()
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
      return
    }

    val channel = NotificationChannel(
      NOTIFICATION_CHANNEL_ID,
      "GPS tracking",
      NotificationManager.IMPORTANCE_LOW
    )

    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    manager.createNotificationChannel(channel)
  }

  companion object {
    private const val LOCATION_INTERVAL_MS = 10000L
    private const val LOCATION_DISTANCE_METERS = 10f
    private const val NOTIFICATION_CHANNEL_ID = "gps_tracker_location"
    private const val NOTIFICATION_ID = 2468

    fun start(context: Context) {
      val intent = Intent(context, GpsTrackerLocationService::class.java)

      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        ContextCompat.startForegroundService(context, intent)
      } else {
        context.startService(intent)
      }
    }

    fun stop(context: Context) {
      context.stopService(Intent(context, GpsTrackerLocationService::class.java))
    }

    @SuppressLint("MissingPermission")
    fun requestSingleLocation(context: Context) {
      if (!hasFineLocationPermission(context)) {
        return
      }

      val locationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
      val lastLocation = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER)

      if (lastLocation != null) {
        GpsTrackerActionRunner.run(context, lastLocation)
      }
    }

    private fun hasFineLocationPermission(context: Context): Boolean {
      return ContextCompat.checkSelfPermission(
        context,
        Manifest.permission.ACCESS_FINE_LOCATION
      ) == PackageManager.PERMISSION_GRANTED
    }

  }
}
