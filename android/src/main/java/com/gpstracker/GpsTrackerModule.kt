package com.gpstracker

import com.facebook.react.bridge.ReactApplicationContext

class GpsTrackerModule(reactContext: ReactApplicationContext) :
  NativeGpsTrackerSpec(reactContext) {

  override fun multiply(a: Double, b: Double): Double {
    return a * b
  }

  companion object {
    const val NAME = NativeGpsTrackerSpec.NAME
  }
}
