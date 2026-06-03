package com.gpstracker.storage

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(
  entities = [GpsTrackerQueuedHttpLocation::class],
  version = 1,
  exportSchema = false
)
abstract class GpsTrackerDatabase : RoomDatabase() {
  abstract fun queueDao(): GpsTrackerQueueDao

  companion object {
    @Volatile
    private var instance: GpsTrackerDatabase? = null

    fun get(context: Context): GpsTrackerDatabase {
      return instance ?: synchronized(this) {
        instance ?: Room.databaseBuilder(
          context.applicationContext,
          GpsTrackerDatabase::class.java,
          "GpsTracker.db"
        ).build().also {
          instance = it
        }
      }
    }
  }
}
