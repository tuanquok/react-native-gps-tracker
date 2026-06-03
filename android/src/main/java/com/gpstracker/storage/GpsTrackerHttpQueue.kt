package com.gpstracker.storage

import android.content.Context
import org.json.JSONObject

object GpsTrackerHttpQueue {
  fun enqueue(context: Context, actionIndex: Int, body: JSONObject): Int {
    val dao = GpsTrackerDatabase.get(context).queueDao()
    dao.insert(
      GpsTrackerQueuedHttpLocation(
        actionIndex = actionIndex,
        body = body.toString()
      )
    )
    return dao.count(actionIndex)
  }

  fun count(context: Context, actionIndex: Int): Int {
    return GpsTrackerDatabase.get(context).queueDao().count(actionIndex)
  }

  fun loadBatch(
    context: Context,
    actionIndex: Int,
    limit: Int
  ): List<GpsTrackerQueuedHttpLocation> {
    return GpsTrackerDatabase.get(context).queueDao().loadBatch(actionIndex, limit)
  }

  fun delete(context: Context, ids: List<Long>) {
    if (ids.isEmpty()) {
      return
    }

    GpsTrackerDatabase.get(context).queueDao().deleteByIds(ids)
  }
}
