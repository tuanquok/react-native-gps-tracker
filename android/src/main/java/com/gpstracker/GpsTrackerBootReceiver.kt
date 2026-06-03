package com.gpstracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.gpstracker.storage.GpsTrackerStore

class GpsTrackerBootReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != Intent.ACTION_BOOT_COMPLETED) {
      return
    }

    if (GpsTrackerStore.isTrackingEnabled(context)) {
      GpsTrackerLocationService.start(context)
    }
  }
}
