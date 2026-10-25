package com.example.vyro.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.example.vyro.MainActivity
import com.example.vyro.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Reads the snapshot written by `VyroHomeWidgets.publish` in Dart.
 * Labels arrive translated; numbers may be stored as Int or Long.
 */
private class Snapshot(prefs: SharedPreferences) {
    private val all = prefs.all

    private fun int(key: String) = (all[key] as? Number)?.toInt() ?: 0
    private fun text(key: String, fallback: String = "") = (all[key] as? String) ?: fallback

    val hasData = all.containsKey("kcal_goal")
    val kcalEaten = int("kcal_eaten")
    val kcalGoal = int("kcal_goal")
    val kcalLeft = int("kcal_left")
    val kcalPercent = int("kcal_percent")
    val proteinEaten = int("protein_eaten")
    val proteinGoal = int("protein_goal")
    val nextWorkout = text("next_workout")
    val nextWhen = text("next_when")
    val weekDone = int("week_done")
    val weekTotal = int("week_total")
    val lblTitle = text("lbl_title", "Hoje")
    val lblLeft = text("lbl_left", "restantes")
    val lblOver = text("lbl_over", "acima do objetivo")
    val lblNext = text("lbl_next", "Próximo treino")
    val lblWeek = text("lbl_week", "treinos feitos")
    val lblProtein = text("lbl_protein", "Proteína")

    val leftLine: String
        get() = if (kcalLeft >= 0) "$kcalLeft kcal $lblLeft" else "${-kcalLeft} kcal $lblOver"
}

private fun openApp(context: Context) =
    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

/** 4×2 widget: calories with progress, protein, next workout and week. */
class VyroTodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val s = Snapshot(widgetData)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_today).apply {
                setOnClickPendingIntent(R.id.widget_root, openApp(context))
                setTextViewText(R.id.widget_title, s.lblTitle.uppercase())
                if (s.hasData) {
                    setTextViewText(R.id.widget_kcal, "${s.kcalEaten}")
                    setTextViewText(R.id.widget_kcal_goal, "/ ${s.kcalGoal} kcal")
                    setProgressBar(R.id.widget_progress, 100, s.kcalPercent, false)
                    setTextViewText(R.id.widget_left, s.leftLine)
                    setTextViewText(
                        R.id.widget_protein,
                        "${s.lblProtein} ${s.proteinEaten} / ${s.proteinGoal} g",
                    )
                    setTextViewText(
                        R.id.widget_next_label,
                        if (s.nextWhen.isBlank()) s.lblNext else "${s.lblNext} · ${s.nextWhen}",
                    )
                    setTextViewText(R.id.widget_next, s.nextWorkout)
                    setTextViewText(R.id.widget_week, "${s.weekDone}/${s.weekTotal} ${s.lblWeek}")
                    setViewVisibility(R.id.widget_empty, View.GONE)
                    setViewVisibility(R.id.widget_content, View.VISIBLE)
                } else {
                    setViewVisibility(R.id.widget_empty, View.VISIBLE)
                    setViewVisibility(R.id.widget_content, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/** 2×2 widget: calories left with a progress bar. */
class VyroCaloriesWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val s = Snapshot(widgetData)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_calories).apply {
                setOnClickPendingIntent(R.id.widget_root, openApp(context))
                setTextViewText(R.id.widget_kcal_left, if (s.hasData) "${kotlin.math.abs(s.kcalLeft)}" else "—")
                setTextViewText(
                    R.id.widget_kcal_caption,
                    if (!s.hasData) "kcal" else if (s.kcalLeft >= 0) "kcal ${s.lblLeft}" else "kcal ${s.lblOver}",
                )
                setProgressBar(R.id.widget_progress, 100, s.kcalPercent, false)
                setTextViewText(R.id.widget_kcal_goal, if (s.hasData) "${s.kcalEaten} / ${s.kcalGoal}" else "")
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
