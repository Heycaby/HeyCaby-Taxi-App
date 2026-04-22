package com.heycaby.rider

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Refreshes when Flutter calls [HomeWidget.updateWidget] with
 * [qualifiedAndroidName] `com.heycaby.rider.HeyCabyHomeWidgetProvider`.
 *
 * Mirrors priority used across WidgetKit providers A–D: on-ride (D), then
 * marketplace (C), scheduled (B), instant / notify (A).
 */
class HeyCabyHomeWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val (title, subtitle, line3, kind) = buildEntry(widgetData)
    appWidgetIds.forEach { widgetId ->
      val views =
          RemoteViews(context.packageName, R.layout.heycaby_home_widget).apply {
            setTextViewText(R.id.heycaby_widget_title, title)
            setTextViewText(R.id.heycaby_widget_subtitle, subtitle)
            setTextViewText(R.id.heycaby_widget_line3, line3)
            val uri = Uri.parse("heycabyrider://widget?kind=$kind")
            val pending = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri)
            setOnClickPendingIntent(R.id.heycaby_widget_root, pending)
          }
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }

  private data class Entry(val title: String, val subtitle: String, val line3: String, val kind: String)

  private fun buildEntry(prefs: SharedPreferences): Entry {
    fun s(key: String, default: String = ""): String = prefs.getString(key, null) ?: default

    val dSt = s("widget_d_status")
    if (dSt == "in_progress") {
      val title = s("widget_d_destination").ifEmpty { "On the way" }
      val min = s("widget_d_minutes_remaining")
      val km = s("widget_d_km_remaining")
      val subtitle =
          when {
            min.isNotEmpty() && km.isNotEmpty() -> "$min min · $km km"
            min.isNotEmpty() -> "$min min"
            km.isNotEmpty() -> "$km km"
            else -> "—"
          }
      return Entry(title, subtitle, s("widget_d_destination_city"), "WidgetD")
    }

    val cSt = s("widget_c_status")
    if (cSt.isNotEmpty() && cSt != "inactive") {
      val n = s("widget_c_bid_count")
      val best = s("widget_c_best_price")
      val title = "Marketplace · $n bids"
      val subtitle = if (best.isNotEmpty()) "Best €$best" else "—"
      val line = "${s("widget_c_origin")} → ${s("widget_c_destination")}"
      return Entry(title, subtitle, line, "WidgetC")
    }

    val bSt = s("widget_b_status")
    if (bSt.isNotEmpty() && bSt != "inactive") {
      val ep = s("widget_b_departure_epoch").toDoubleOrNull() ?: 0.0
      val depMs = (ep * 1000).toLong()
      val remMin = ((depMs - System.currentTimeMillis()) / 60_000).toInt()
      val origin = s("widget_b_origin")
      val dest = s("widget_b_destination")
      if (bSt == "driver_assigned") {
        val name = s("widget_b_driver_name")
        val car = s("widget_b_car")
        val depLine = if (remMin > 0) "Departs in $remMin min" else "Departing"
        return Entry("Driver ready", "$name · $car", depLine, "WidgetB")
      }
      val subtitle = if (remMin > 0) "In $remMin min" else "Departing"
      return Entry("Scheduled ride", subtitle, "$origin → $dest", "WidgetB")
    }

    val aSt = s("widget_a_status")
    if (aSt.isEmpty() || aSt == "inactive") {
      return Entry("HeyCaby", "No active ride", "", "WidgetA")
    }
    if (aSt == "driver_found") {
      val name = s("widget_a_driver_name")
      val car = s("widget_a_car")
      return Entry("Driver found", "$name · $car", s("widget_a_pickup"), "WidgetA")
    }
    if (aSt == "notify_background") {
      val dest = s("widget_a_destination")
      val pickup = s("widget_a_pickup")
      val route = if (dest.isNotEmpty()) dest else pickup
      val elapsed = s("widget_a_search_elapsed")
      val sub = if (route.isEmpty()) "HeyCaby" else route
      return Entry(
          "Searching for driver",
          sub,
          "Still matching · ${elapsed}s · tap to open",
          "WidgetA",
      )
    }
    val elapsed = s("widget_a_search_elapsed")
    return Entry("Searching…", "${elapsed}s", s("widget_a_pickup"), "WidgetA")
  }
}
