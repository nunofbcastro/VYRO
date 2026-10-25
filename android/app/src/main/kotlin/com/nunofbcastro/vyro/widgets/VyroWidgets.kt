package com.nunofbcastro.vyro.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import com.nunofbcastro.vyro.MainActivity
import com.nunofbcastro.vyro.R
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
    val lblScan = text("lbl_scan", "Código")
    val lblPhoto = text("lbl_photo", "Foto")
    val lblManual = text("lbl_manual", "Manual")
    val lblStart = text("lbl_start", "Começar")
    val lblTraining = text("lbl_training", "Treino da semana")
    val weekLabels = text("week_labels").split(',').filter { it.isNotBlank() }
    val weekStatus = text("week_status").split(',').filter { it.isNotBlank() }

    val leftLine: String
        get() = if (kcalLeft >= 0) "$kcalLeft kcal $lblLeft" else "${-kcalLeft} kcal $lblOver"
}

private fun openApp(context: Context) =
    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

/** Opens the app straight on a screen (handled by LaunchActions in Dart). */
private fun action(context: Context, id: String) =
    HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse("vyro://action/$id"),
    )

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
                    setTextViewText(R.id.btn_scan, "+ ${s.lblScan}")
                    setTextViewText(R.id.btn_photo, s.lblPhoto)
                    setTextViewText(R.id.btn_manual, s.lblManual)
                    setOnClickPendingIntent(R.id.btn_scan, action(context, "scan"))
                    setOnClickPendingIntent(R.id.btn_photo, action(context, "photo"))
                    setOnClickPendingIntent(R.id.btn_manual, action(context, "manual"))
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
                setOnClickPendingIntent(R.id.widget_root, action(context, "manual"))
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

/** 4×2 widget: Monday–Sunday status, next workout and a start button. */
class VyroTrainingWidgetProvider : HomeWidgetProvider() {
    private val dayIds = intArrayOf(
        R.id.day_0, R.id.day_1, R.id.day_2, R.id.day_3, R.id.day_4, R.id.day_5, R.id.day_6,
    )
    private val labelIds = intArrayOf(
        R.id.day_label_0, R.id.day_label_1, R.id.day_label_2, R.id.day_label_3,
        R.id.day_label_4, R.id.day_label_5, R.id.day_label_6,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val s = Snapshot(widgetData)
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_training).apply {
                setOnClickPendingIntent(R.id.widget_root, action(context, "training"))
                setOnClickPendingIntent(R.id.widget_start, action(context, "training"))
                setTextViewText(R.id.widget_title, s.lblTraining)
                setTextViewText(R.id.widget_start, s.lblStart)
                setTextViewText(R.id.widget_week, if (s.hasData) "${s.weekDone}/${s.weekTotal}" else "")
                for (i in 0 until 7) {
                    val status = s.weekStatus.getOrNull(i) ?: "rest"
                    setTextViewText(labelIds[i], s.weekLabels.getOrNull(i) ?: "")
                    val (background, glyph, color) = when (status) {
                        "done" -> Triple(R.drawable.widget_day_done, "✓", Color.parseColor("#0B0D10"))
                        "today" -> Triple(R.drawable.widget_day_today, "•", Color.parseColor("#B8F36B"))
                        "missed" -> Triple(R.drawable.widget_day_missed, "!", Color.parseColor("#E4796F"))
                        "skipped" -> Triple(R.drawable.widget_day_skipped, "–", Color.parseColor("#9299A4"))
                        "planned" -> Triple(R.drawable.widget_day_planned, "•", Color.parseColor("#F5F7F8"))
                        else -> Triple(R.drawable.widget_day_rest, "", Color.parseColor("#9299A4"))
                    }
                    setInt(dayIds[i], "setBackgroundResource", background)
                    setTextViewText(dayIds[i], glyph)
                    setTextColor(dayIds[i], color)
                }
                setTextViewText(
                    R.id.widget_next_label,
                    if (s.nextWhen.isBlank()) s.lblNext else "${s.lblNext} · ${s.nextWhen}",
                )
                setTextViewText(R.id.widget_next, s.nextWorkout)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
