package com.example.expense_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews

import es.antonborri.home_widget.HomeWidgetProvider

class SmallExpenseWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout_small).apply {
                // Open App on Click - Reuse logic from parent
                val pendingIntent = ExpenseWidgetProvider.launchApp(context)
                setOnClickPendingIntent(R.id.icon, pendingIntent) // ID is 'icon' in small layout container
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
