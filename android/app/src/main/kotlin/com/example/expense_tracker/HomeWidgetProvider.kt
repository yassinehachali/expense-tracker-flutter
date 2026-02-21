package com.example.expense_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import android.content.Intent
import android.app.PendingIntent
import com.example.expense_tracker.MainActivity

class ExpenseWidgetProvider : HomeWidgetProvider() {

    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val action = intent.action
        
        if (action == "com.example.expense_tracker.ACTION_ADD_INCOME") {
            prefs.edit().putBoolean("flutter.widget_launch_add_income", true).apply()
            launchApp(context)
        } else if (action == "com.example.expense_tracker.ACTION_ADD_EXPENSE") {
            prefs.edit().putBoolean("flutter.widget_launch_add_expense", true).apply()
            launchApp(context) 
        }
        super.onReceive(context, intent)
    }

    private fun launchApp(context: Context) {
        val launchIntent = Intent(context, MainActivity::class.java)
        launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(launchIntent)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                // Bind Income Button
                setOnClickPendingIntent(R.id.btn_income, getPendingIntent(context, "com.example.expense_tracker.ACTION_ADD_INCOME"))
                
                // Bind Expense Button
                setOnClickPendingIntent(R.id.btn_expense, getPendingIntent(context, "com.example.expense_tracker.ACTION_ADD_EXPENSE"))

                // Update Text (Today's Expense) - Read from SharedPrefs (written by Flutter)
                // Note: We use widgetData (passed by home_widget) which maps to the default SharedPreferences used by HomeWidget plugin
                // BUT we need to access the FLUTTER shared prefs "FlutterSharedPreferences" if we wrote it there.
                // However, home_widget usually syncs data via its own mechanism. 
                // Let's rely on `widgetData` which comes from `HomeWidget.saveWidgetData` in Flutter.
                val todayExpense = widgetData.getString("today_expense", "$ 0.00")
                setTextViewText(R.id.widget_amount, todayExpense)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
    
    companion object {
        fun getPendingIntent(context: Context, action: String): PendingIntent {
            val intent = Intent(context, ExpenseWidgetProvider::class.java)
            intent.action = action
            return PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        
        // Helper for Small Widget compatibility (it calls launchApp directly)
        // We map it to ADD_EXPENSE by default
        fun getClickIntent(context: Context): PendingIntent {
            return getPendingIntent(context, "com.example.expense_tracker.ACTION_ADD_EXPENSE") 
        }

        fun launchApp(context: Context): PendingIntent {
             return getClickIntent(context)
        }
    }
}
