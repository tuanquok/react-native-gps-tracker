package com.gpstracker

import android.content.Context
import android.location.Location
import com.gpstracker.storage.GpsTrackerHttpQueue
import com.gpstracker.storage.GpsTrackerStore
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
          runHttpAction(context, index, action, locationPayload)
        }

        "file" -> executor.execute {
          writeFileAction(context, action, locationPayload)
        }
      }
    }
  }

  fun sync(context: Context) {
    val config = GpsTrackerStore.loadConfig(context) ?: return
    val actions = config.optJSONArray("actions") ?: return

    for (index in 0 until actions.length()) {
      val action = actions.optJSONObject(index) ?: continue
      if (action.optString("type") != "http" || !action.optBoolean("batchSync", false)) {
        continue
      }

      executor.execute {
        flushBatchHttpAction(context, index, action)
      }
    }
  }

  private fun runHttpAction(
    context: Context,
    actionIndex: Int,
    action: JSONObject,
    locationPayload: JSONObject
  ) {
    val bodyTemplate = actionValue(action, "body") ?: locationPayload
    val body = renderTemplate(bodyTemplate, locationPayload)

    if (!action.optBoolean("batchSync", false)) {
      sendHttpAction(action, body)
      return
    }

    val locationBody = body as? JSONObject
    if (locationBody == null) {
      println("GpsTracker batch action skipped: body must be a JSON object")
      return
    }

    val queueSize = GpsTrackerHttpQueue.enqueue(context, actionIndex, locationBody)
    if (!action.optBoolean("autoSync", true)) {
      return
    }

    val requiredBatchSize = requiredAutoSyncBatchSize(action)
    println("GpsTracker batch queued: $queueSize/$requiredBatchSize")
    if (queueSize >= requiredBatchSize) {
      flushBatchHttpAction(context, actionIndex, action)
    }
  }

  private fun flushBatchHttpAction(
    context: Context,
    actionIndex: Int,
    action: JSONObject
  ) {
    val queueSize = GpsTrackerHttpQueue.count(context, actionIndex)
    val requiredBatchSize = requiredAutoSyncBatchSize(action)
    if (requiredBatchSize <= 0 || queueSize < requiredBatchSize) {
      println("GpsTracker batch sync skipped: $queueSize/$requiredBatchSize queued")
      return
    }

    val batchSize = resolveBatchSize(action, queueSize)
    val batch = GpsTrackerHttpQueue.loadBatch(context, actionIndex, batchSize)
    if (batch.isEmpty()) {
      return
    }

    val locations = JSONArray()
    for (location in batch) {
      locations.put(JSONObject(location.body))
    }

    val batchPayload = JSONObject().put("locations", locations)
    val bodyTemplate = actionValue(action, "batchBody") ?: locations
    val body = renderTemplate(bodyTemplate, batchPayload)

    println("GpsTracker batch sync sending: ${batch.size} locations")
    if (sendHttpAction(action, body)) {
      GpsTrackerHttpQueue.delete(context, batch.map { it.id })
      println("GpsTracker batch sync deleted: ${batch.size} locations")
    }
  }

  private fun sendHttpAction(action: JSONObject, body: Any): Boolean {
    val urlString = action.optString("url")
    if (urlString.isBlank()) {
      return false
    }

    val connection = URL(urlString).openConnection() as HttpURLConnection

    return try {
      val timeout = action.optInt("timeoutMs", 30000)
      connection.requestMethod = action.optString("method", "POST")
      connection.connectTimeout = timeout
      connection.readTimeout = timeout
      connection.doOutput = true

      val headers = action.optJSONObject("headers")
      if (headers != null) {
        val keys = headers.keys()
        while (keys.hasNext()) {
          val key = keys.next()
          connection.setRequestProperty(key, headers.optString(key))
        }
      }

      if (connection.getRequestProperty("Content-Type") == null) {
        connection.setRequestProperty("Content-Type", "application/json")
      }

      OutputStreamWriter(connection.outputStream).use { writer ->
        writer.write(body.toString())
      }

      connection.responseCode in 200..299
    } catch (error: Exception) {
      println("GpsTracker http action failed: $error")
      false
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

  private fun actionValue(action: JSONObject, key: String): Any? {
    if (!action.has(key) || action.isNull(key)) {
      return null
    }

    return action.opt(key)
  }

  private fun requiredAutoSyncBatchSize(action: JSONObject): Int {
    val maxBatchSize = action.optInt("maxBatchSize", 0)
    if (maxBatchSize > 0) {
      return maxBatchSize
    }

    return maxOf(action.optInt("autoSyncThreshold", 1), 1)
  }

  private fun resolveBatchSize(action: JSONObject, queueSize: Int): Int {
    val maxBatchSize = action.optInt("maxBatchSize", 0)
    if (maxBatchSize <= 0) {
      return queueSize
    }

    return minOf(maxBatchSize, queueSize)
  }

  private const val DEFAULT_LOCATION_LOG_FILE = "gps-tracker-locations.txt"
}
