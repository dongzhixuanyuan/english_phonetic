package com.liudong.bookread.service

import android.content.Context
import android.util.Log
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

object PhoneticDictionaryService {
    private var phoneticDict: MutableMap<String, String> = mutableMapOf()
    private var meaningDict: MutableMap<String, String> = mutableMapOf()
    private const val USER_EXTENSIONS_KEY = "user_phonetic_extensions"
    private val json = Json { ignoreUnknownKeys = true }

    fun loadDictionary(context: Context) {
        try {
            context.assets.open("phonetic_dictionary.json").use { stream ->
                val content = stream.bufferedReader().readText()
                val map: Map<String, Map<String, String>> = json.decodeFromString(content)
                for ((word, info) in map) {
                    val key = word.lowercase()
                    phoneticDict[key] = info["phonetic"] ?: ""
                    meaningDict[key] = info["meaning"] ?: ""
                }
            }
        } catch (e: Exception) {
            Log.w("PhoneticDict", "基础词库加载失败或不存在", e)
        }

        val prefs = context.getSharedPreferences("phonetic_prefs", Context.MODE_PRIVATE)
        val saved = prefs.getString(USER_EXTENSIONS_KEY, null)
        saved?.let {
            try {
                val extensions: Map<String, String> = json.decodeFromString(it)
                phoneticDict.putAll(extensions.mapKeys { entry -> entry.key.lowercase() })
            } catch (e: Exception) {
                Log.w("PhoneticDict", "用户扩展词库加载失败", e)
            }
        }

        Log.d("PhoneticDict", "音标词库加载完成，共 ${phoneticDict.size} 个单词")
    }

    fun lookup(word: String): String? {
        val clean = word.lowercase().trim { it in ".,;:!?\"'()[]{}" }
        return phoneticDict[clean]?.takeIf { it.isNotEmpty() }
    }

    fun lookupMeaning(word: String): String? {
        val clean = word.lowercase().trim { it in ".,;:!?\"'()[]{}" }
        return meaningDict[clean]?.takeIf { it.isNotEmpty() }
    }

    fun addCustomPhonetic(context: Context, word: String, phonetic: String) {
        val key = word.lowercase()
        phoneticDict[key] = phonetic
        saveUserExtensions(context)
    }

    private fun saveUserExtensions(context: Context) {
        val prefs = context.getSharedPreferences("phonetic_prefs", Context.MODE_PRIVATE)
        val mapToSave: Map<String, String> = phoneticDict
        prefs.edit().putString(USER_EXTENSIONS_KEY, json.encodeToString(mapToSave)).apply()
    }
}
