package com.gpstracker

import android.content.Context
import com.facebook.react.bridge.ReadableMap
import org.json.JSONObject

object GpsTrackerStore {
  const val PREFERENCES_NAME = "GpsTracker"
  const val CONFIG_KEY = "GpsTracker.config"
  const val TRACKING_ENABLED_KEY = "GpsTracker.trackingEnabled"

  fun saveConfig(context: Context, config: ReadableMap) {
    val json = JSONObject(config.toHashMap()).toString()
    preferences(context)
      .edit()
      .putString(CONFIG_KEY, json)
      .apply()
  }

  fun loadConfig(context: Context): JSONObject? {
    val json = preferences(context).getString(CONFIG_KEY, null)
    return json?.let { JSONObject(it) }
  }

  fun setTrackingEnabled(context: Context, enabled: Boolean) {
    preferences(context)
      .edit()
      .putBoolean(TRACKING_ENABLED_KEY, enabled)
      .apply()
  }

  fun isTrackingEnabled(context: Context): Boolean {
    return preferences(context).getBoolean(TRACKING_ENABLED_KEY, false)
  }

  private fun preferences(context: Context) =
    context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
}
