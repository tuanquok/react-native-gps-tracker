package com.gpstracker.storage

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao
interface GpsTrackerQueueDao {
    @Insert
    fun insert(location: GpsTrackerQueuedHttpLocation): Long

    @Query(
        """
    SELECT COUNT(*)
    FROM http_locations
    WHERE action_index = :actionIndex
    """
    )
    fun count(actionIndex: Int): Int

    @Query(
        """
    SELECT *
    FROM http_locations
    WHERE action_index = :actionIndex
    ORDER BY id ASC
    LIMIT :limit
    """
    )
    fun loadBatch(actionIndex: Int, limit: Int): List<GpsTrackerQueuedHttpLocation>

    @Query("DELETE FROM http_locations WHERE id IN (:ids)")
    fun deleteByIds(ids: List<Long>)
}
