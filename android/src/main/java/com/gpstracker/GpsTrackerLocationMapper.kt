package com.gpstracker

import android.location.Location
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import org.json.JSONObject

object GpsTrackerLocationMapper {
  fun toPayload(location: Location): JSONObject {
    return JSONObject()
      .put("latitude", location.latitude)
      .put("longitude", location.longitude)
      .put("accuracy", location.accuracy.toDouble())
      .put("altitude", location.altitude)
      .put("speed", location.speed.toDouble())
      .put("course", location.bearing.toDouble())
      .put("timestamp", isoDate(location.time))
  }

  private fun isoDate(timestamp: Long): String {
    val formatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
    formatter.timeZone = TimeZone.getTimeZone("UTC")
    return formatter.format(Date(timestamp))
  }
}
