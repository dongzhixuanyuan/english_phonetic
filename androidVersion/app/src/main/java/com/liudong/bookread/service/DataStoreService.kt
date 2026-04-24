package com.liudong.bookread.service

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.liudong.bookread.model.Textbook
import kotlinx.coroutines.flow.first
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

private val Context.dataStore by preferencesDataStore(name = "app_preferences")

object DataStoreService {
    private const val TEXTBOOKS_KEY = "saved_textbooks"
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun saveTextbooks(context: Context, textbooks: List<Textbook>) {
        val jsonStr = json.encodeToString(textbooks)
        context.dataStore.edit { prefs ->
            prefs[stringPreferencesKey(TEXTBOOKS_KEY)] = jsonStr
        }
    }

    suspend fun loadTextbooks(context: Context): List<Textbook> {
        val prefs = context.dataStore.data.first()
        val jsonStr = prefs[stringPreferencesKey(TEXTBOOKS_KEY)] ?: return emptyList()
        return try {
            json.decodeFromString(jsonStr)
        } catch (e: Exception) {
            Log.e("DataStore", "加载课本数据失败", e)
            emptyList()
        }
    }

    fun saveImage(context: Context, bitmap: Bitmap, pageId: String): String? {
        val filename = "$pageId.jpg"
        val file = File(context.filesDir, filename)
        return try {
            file.outputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out)
            }
            filename
        } catch (e: Exception) {
            Log.e("DataStore", "保存图片失败", e)
            null
        }
    }

    fun loadImage(context: Context, filename: String): Bitmap? {
        val file = File(context.filesDir, filename)
        return if (file.exists()) BitmapFactory.decodeFile(file.absolutePath) else null
    }

    fun deleteImage(context: Context, filename: String) {
        File(context.filesDir, filename).delete()
    }
}
