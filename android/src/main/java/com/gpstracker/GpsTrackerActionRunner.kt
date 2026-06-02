                               package com.gpstracker

import android.content.Context
import android.location.Location
import java.io.File
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import org.json.JSONArray
import org.json.JSONObject

object GpsTrackerActionRunner {
  private val executor = Executors.newSingleThreadExecutor()

  fun run(context: Context, location: Location) {
    val config = GpsTrackerStore.loadConfig(context) ?: return
    val actions = config.optJSONArray("actions") ?: return
    val locationPayload = GpsTrackerLocationMapper.toPayload(location)

    for (index in 0 until actions.length()) {
      val action = actions.optJSONObject(index) ?: continue

      when (action.optString("type")) {
        "http" -> executor.execute {
          sendHttpAction(action, locationPayload)
        }

        "file" -> executor.execute {
          writeFileAction(context, action, locationPayload)
        }
      }
    }
  }

  private fun sendHttpAction(action: JSONObject, locationPayload: JSONObject) {
    val urlString = action.optString("url")
    if (urlString.isBlank()) {
      return
    }

    val connection = URL(urlString).openConnection() as HttpURLConnection

    try {
      val timeout = action.optInt("timeoutMs", 30000)
      connection.requestMethod = action.optString("method", "POST")
      connection.connectTimeout = timeout
      connection.readTimeout = timeout
      connection.doOutput = true
      connection.setRequestProperty("Content-Type", "application/json")

      val headers = action.optJSONObject("headers")
      if (headers != null) {
        val keys = headers.keys()
        while (keys.hasNext()) {
          val key = keys.next()
          connection.setRequestProperty(key, headers.optString(key))
        }
      }

      val bodyTemplate = action.optJSONObject("body") ?: locationPayload
      val body = renderTemplate(bodyTemplate, locationPayload)

      OutputStreamWriter(connection.outputStream).use { writer ->
        writer.write(body.toString())
      }

      connection.responseCode
    } finally {
      connection.disconnect()
    }
  }

  private fun writeFileAction(
    context: Context,
    action: JSONObject,
    locationPayload: JSONObject
  ) {
    val fileName = action.optString("fileName", DEFAULT_LOCATION_LOG_FILE)
    val file = File(context.getExternalFilesDir(null), fileName)

    file.parentFile?.mkdirs()
    file.appendText("${locationPayload}\n")
  }

  private fun renderTemplate(value: Any, locationPayload: JSONObject): Any {
    return when (value) {
      is JSONObject -> {
        val output = JSONObject()
        val keys = value.keys()
        while (keys.hasNext()) {
          val key = keys.next()
          output.put(key, renderTemplate(value.get(key), locationPayload))
        }
        output
      }

      is JSONArray -> {
        val output = JSONArray()
        for (index in 0 until value.length()) {
          output.put(renderTemplate(value.get(index), locationPayload))
        }
        output
      }

      is String -> {
        if (value.startsWith("$")) {
          locationPayload.opt(value.drop(1)) ?: value
        } else {
          value
        }
      }

      else -> value
    }
  }

  private const val DEFAULT_LOCATION_LOG_FILE = "gps-tracker-locations.txt"
}
