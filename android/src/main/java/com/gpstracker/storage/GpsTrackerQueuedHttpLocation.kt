package com.gpstracker.storage

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "http_locations")
data class GpsTrackerQueuedHttpLocation(
  @PrimaryKey(autoGenerate = true)
  val id: Long = 0,

  @ColumnInfo(name = "action_index")
  val actionIndex: Int,

  val body: String,

  @ColumnInfo(name = "created_at")
  val createdAt: Long = System.currentTimeMillis()
)
