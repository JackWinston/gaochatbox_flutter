package com.gao.chatbox.flutter

import android.content.Context
import android.graphics.Color
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.cardview.widget.CardView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * 调试日志原生视图 — Android 侧实现。
 *
 * 使用 RecyclerView + CardView 渲染日志列表，
 * 通过 MethodChannel 与 Flutter 侧通信（长按复制、下拉刷新）。
 */
class DebugLogPlatformView(
    context: Context,
    id: Int,
    creationParams: Map<*, *>?,
    private val channel: MethodChannel,
) : PlatformView {

    private val recyclerView: RecyclerView = RecyclerView(context).apply {
        layoutManager = LinearLayoutManager(context)
        setPadding(32, 32, 32, 32)
        clipToPadding = false
    }

    init {
        val entries: List<*> = (creationParams?.get("entries") as? List<*>) ?: emptyList<Any>()
        val colors: Map<*, *> = (creationParams?.get("colors") as? Map<*, *>) ?: emptyMap<Any, Any>()

        val surfaceColor = (colors["surfaceContainerLow"] as? Int)?.let { Color.argb(
            (it shr 24) and 0xFF, (it shr 16) and 0xFF, (it shr 8) and 0xFF, it and 0xFF
        ) } ?: Color.parseColor("#F5F5F5")

        val onSurfaceColor = (colors["onSurface"] as? Int)?.let { Color.argb(
            (it shr 24) and 0xFF, (it shr 16) and 0xFF, (it shr 8) and 0xFF, it and 0xFF
        ) } ?: Color.parseColor("#1C1B1F")

        val primaryColor = (colors["primary"] as? Int)?.let { Color.argb(
            (it shr 24) and 0xFF, (it shr 16) and 0xFF, (it shr 8) and 0xFF, it and 0xFF
        ) } ?: Color.parseColor("#6750A4")

        val errorContainerColor = (colors["errorContainer"] as? Int)?.let { Color.argb(
            (it shr 24) and 0xFF, (it shr 16) and 0xFF, (it shr 8) and 0xFF, it and 0xFF
        ) } ?: Color.parseColor("#F9DEDC")

        val outlineVariantColor = (colors["outlineVariant"] as? Int)?.let { Color.argb(
            (it shr 24) and 0xFF, (it shr 16) and 0xFF, (it shr 8) and 0xFF, it and 0xFF
        ) } ?: Color.parseColor("#CAC4D0")

        val parsedEntries = entries.mapNotNull { item ->
            @Suppress("UNCHECKED_CAST")
            (item as? Map<String, Any>)?.let { map ->
                LogEntry(
                    type = map["type"] as? String ?: "",
                    timestamp = map["timestamp"] as? String ?: "",
                    url = map["url"] as? String ?: "",
                    requestBody = map["requestBody"] as? String ?: "",
                    responseBody = map["responseBody"] as? String ?: "",
                    isError = map["isError"] as? Boolean ?: false,
                )
            }
        }

        recyclerView.adapter = LogEntryAdapter(
            entries = parsedEntries,
            surfaceColor = surfaceColor,
            onSurfaceColor = onSurfaceColor,
            primaryColor = primaryColor,
            errorContainerColor = errorContainerColor,
            outlineVariantColor = outlineVariantColor,
            onLongClick = { index ->
                channel.invokeMethod("onCopyEntry", index)
            },
        )
    }

    override fun getView(): View = recyclerView

    override fun dispose() {}

    private data class LogEntry(
        val type: String,
        val timestamp: String,
        val url: String,
        val requestBody: String,
        val responseBody: String,
        val isError: Boolean,
    )

    private class LogEntryAdapter(
        private val entries: List<LogEntry>,
        private val surfaceColor: Int,
        private val onSurfaceColor: Int,
        private val primaryColor: Int,
        private val errorContainerColor: Int,
        private val outlineVariantColor: Int,
        private val onLongClick: (Int) -> Unit,
    ) : RecyclerView.Adapter<LogEntryAdapter.ViewHolder>() {

        class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val card: CardView = view.findViewById(1)
            val typeText: TextView = view.findViewById(2)
            val timestampText: TextView = view.findViewById(3)
            val errorBadge: TextView = view.findViewById(4)
            val urlLabel: TextView = view.findViewById(5)
            val urlContent: TextView = view.findViewById(6)
            val requestLabel: TextView = view.findViewById(7)
            val requestContent: TextView = view.findViewById(8)
            val responseLabel: TextView = view.findViewById(9)
            val responseContent: TextView = view.findViewById(10)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val context = parent.context
            val dp = context.resources.displayMetrics.density

            // 以纯代码方式构建 item 布局，无需 XML
            val card = CardView(context).apply {
                id = 1
                radius = 18 * dp
                cardElevation = 0f
                setCardBackgroundColor(surfaceColor)
                setContentPadding(
                    (16 * dp).toInt(), (16 * dp).toInt(),
                    (16 * dp).toInt(), (16 * dp).toInt()
                )
                layoutParams = ViewGroup.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                )
                // 设置描边
                outlineProvider = android.view.ViewOutlineProvider.BACKGROUND
                clipToOutline = true
            }

            val rootLayout = android.widget.LinearLayout(context).apply {
                orientation = android.widget.LinearLayout.VERTICAL
            }

            val headerRow = android.widget.LinearLayout(context).apply {
                orientation = android.widget.LinearLayout.HORIZONTAL
                gravity = android.view.Gravity.TOP
            }

            val headerTexts = android.widget.LinearLayout(context).apply {
                orientation = android.widget.LinearLayout.VERTICAL
                layoutParams = android.widget.LinearLayout.LayoutParams(
                    0, android.widget.LinearLayout.LayoutParams.WRAP_CONTENT, 1f
                )
            }

            val typeText = TextView(context).apply {
                id = 2
                textSize = 16f
                setTextColor(onSurfaceColor)
                typeface = android.graphics.Typeface.DEFAULT_BOLD
            }

            val timestampText = TextView(context).apply {
                id = 3
                textSize = 12f
                setTextColor(onSurfaceColor)
            }

            headerTexts.addView(typeText)
            headerTexts.addView(timestampText)

            val errorBadge = TextView(context).apply {
                id = 4
                textSize = 12f
                visibility = View.GONE
                setPadding(
                    (10 * dp).toInt(), (4 * dp).toInt(),
                    (10 * dp).toInt(), (4 * dp).toInt()
                )
                background = android.graphics.drawable.GradientDrawable().apply {
                    cornerRadius = 999 * dp
                    setColor(errorContainerColor)
                }
            }

            headerRow.addView(headerTexts)
            headerRow.addView(errorBadge)
            rootLayout.addView(headerRow)

            // URL section
            val urlLabel = TextView(context).apply {
                id = 5
                text = "URL"
                textSize = 14f
                setTextColor(primaryColor)
            }
            val urlContent = TextView(context).apply {
                id = 6
                textSize = 14f
                setTextColor(onSurfaceColor)
                setTextIsSelectable(true)
            }

            // Request section
            val requestLabel = TextView(context).apply {
                id = 7
                textSize = 14f
                setTextColor(primaryColor)
                visibility = View.GONE
            }
            val requestContent = TextView(context).apply {
                id = 8
                textSize = 14f
                setTextColor(onSurfaceColor)
                setTextIsSelectable(true)
                visibility = View.GONE
            }

            // Response section
            val responseLabel = TextView(context).apply {
                id = 9
                textSize = 14f
                setTextColor(primaryColor)
                visibility = View.GONE
            }
            val responseContent = TextView(context).apply {
                id = 10
                textSize = 14f
                setTextColor(onSurfaceColor)
                setTextIsSelectable(true)
                visibility = View.GONE
            }

            // 各 section 间距
            fun addSpacer(heightDp: Int) {
                rootLayout.addView(View(context).apply {
                    layoutParams = android.widget.LinearLayout.LayoutParams(
                        android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                        (heightDp * dp).toInt(),
                    )
                })
            }

            addSpacer(10)
            rootLayout.addView(urlLabel)
            addSpacer(6)
            rootLayout.addView(urlContent)
            addSpacer(12)
            rootLayout.addView(requestLabel)
            addSpacer(6)
            rootLayout.addView(requestContent)
            addSpacer(12)
            rootLayout.addView(responseLabel)
            addSpacer(6)
            rootLayout.addView(responseContent)

            card.addView(rootLayout)

            return ViewHolder(card).apply {
                // 长按复制
                card.setOnLongClickListener {
                    onLongClick(adapterPosition)
                    true
                }
            }
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val entry = entries[position]
            holder.typeText.text = entry.type
            holder.timestampText.text = entry.timestamp

            if (entry.isError) {
                holder.errorBadge.visibility = View.VISIBLE
                holder.errorBadge.text = "Error"
                holder.errorBadge.setTextColor(Color.parseColor("#B3261E"))
            } else {
                holder.errorBadge.visibility = View.GONE
            }

            holder.urlContent.text = entry.url

            if (entry.requestBody.isNotEmpty()) {
                holder.requestLabel.visibility = View.VISIBLE
                holder.requestLabel.text = "Request"
                holder.requestContent.visibility = View.VISIBLE
                holder.requestContent.text = entry.requestBody
            } else {
                holder.requestLabel.visibility = View.GONE
                holder.requestContent.visibility = View.GONE
            }

            if (entry.responseBody.isNotEmpty()) {
                holder.responseLabel.visibility = View.VISIBLE
                holder.responseLabel.text = "Response"
                holder.responseContent.visibility = View.VISIBLE
                holder.responseContent.text = entry.responseBody
            } else {
                holder.responseLabel.visibility = View.GONE
                holder.responseContent.visibility = View.GONE
            }
        }

        override fun getItemCount() = entries.size
    }
}

/**
 * PlatformViewFactory — 注册到 FlutterEngine。
 */
class DebugLogViewFactory(
    private val channel: MethodChannel,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        @Suppress("UNCHECKED_CAST")
        val creationParams = args as? Map<*, *>
        return DebugLogPlatformView(context, viewId, creationParams, channel)
    }
}
