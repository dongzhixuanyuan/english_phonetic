package com.liudong.bookread.service

import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.Locale

object SpeechService {
    private var tts: TextToSpeech? = null
    private var isInitialized = false

    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking.asStateFlow()

    private val _currentWord = MutableStateFlow<String?>(null)
    val currentWord: StateFlow<String?> = _currentWord.asStateFlow()

    private val _isAvailable = MutableStateFlow(false)
    val isAvailable: StateFlow<Boolean> = _isAvailable.asStateFlow()

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage.asStateFlow()

    var accent: String = "en-US"
    var speechRate: Float = 1.0f

    // 记录已经尝试过的引擎，避免死循环
    private val attemptedEngines = mutableSetOf<String>()

    fun initialize(context: Context) {
        if (isInitialized) return
        attemptedEngines.clear()

        val mainHandler = Handler(Looper.getMainLooper())

        val tempTts = TextToSpeech(context) { status ->
            mainHandler.post {
                val currentTts = tts ?: return@post
                handleInitResult(currentTts, status, context)
            }
        }

        tts = tempTts
    }

    private fun handleInitResult(currentTts: TextToSpeech, status: Int, context: Context) {
        val engines = currentTts.engines
        Log.i("SpeechService", "设备上共有 ${engines.size} 个 TTS 引擎:")
        engines.forEach { engine ->
            Log.i("SpeechService", "  - ${engine.name} (label=${engine.label})")
        }

        if (status == TextToSpeech.SUCCESS) {
            trySetupLanguage(currentTts, context)
            return
        }

        // 默认引擎初始化失败，尝试其他已安装引擎
        Log.e("SpeechService", "默认 TTS 引擎初始化失败，status=$status，尝试切换引擎...")

        val nextEngine = engines.firstOrNull { it.name !in attemptedEngines }
        if (nextEngine != null) {
            attemptedEngines.add(nextEngine.name)
            Log.i("SpeechService", "尝试切换到引擎: ${nextEngine.name}")
            currentTts.shutdown()

            val mainHandler = Handler(Looper.getMainLooper())
            val newTts = TextToSpeech(context, { newStatus ->
                mainHandler.post {
                    val latestTts = tts ?: return@post
                    handleInitResult(latestTts, newStatus, context)
                }
            }, nextEngine.name)
            tts = newTts
            return
        }

        // 所有引擎都试过了，还是失败
        Log.e("SpeechService", "所有 TTS 引擎均初始化失败")
        _errorMessage.value = "语音引擎无法启动，请前往「设置 → 辅助功能 → 文字转语音」将科大讯飞设为默认引擎"
        _isAvailable.value = false
        currentTts.shutdown()
    }

    private fun trySetupLanguage(currentTts: TextToSpeech, context: Context) {
        val locale = Locale.US
        val langResult = currentTts.setLanguage(locale)
        Log.i("SpeechService", "setLanguage(Locale.US) 返回: $langResult")

        if (langResult == TextToSpeech.LANG_MISSING_DATA) {
            Log.e("SpeechService", "英语语音数据缺失")
            _errorMessage.value = "英语语音数据缺失，请在系统设置中下载语音包"
            _isAvailable.value = false
            currentTts.shutdown()
            return
        }

        if (langResult == TextToSpeech.LANG_NOT_SUPPORTED) {
            Log.e("SpeechService", "当前 TTS 引擎不支持英语")
            _errorMessage.value = "当前语音引擎不支持英语"
            _isAvailable.value = false
            currentTts.shutdown()
            return
        }

        isInitialized = true
        _isAvailable.value = true
        _errorMessage.value = null

        currentTts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                _isSpeaking.value = true
            }
            override fun onDone(utteranceId: String?) {
                _isSpeaking.value = false
                _currentWord.value = null
            }
            override fun onError(utteranceId: String?) {
                _isSpeaking.value = false
                _currentWord.value = null
            }
        })

        Log.i("SpeechService", "TTS 初始化成功，使用引擎: ${currentTts.defaultEngine}")
    }

    fun speak(word: String) {
        if (!isInitialized || !_isAvailable.value) {
            Log.w("SpeechService", "TTS 不可用，跳过发音: $word")
            return
        }
        tts?.stop()
        _currentWord.value = word
        _isSpeaking.value = true

        val locale = when (accent) {
            "en-GB" -> Locale.UK
            else -> Locale.US
        }
        tts?.language = locale
        tts?.setSpeechRate(speechRate)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            tts?.speak(word, TextToSpeech.QUEUE_FLUSH, null, word)
        }
    }

    fun stop() {
        tts?.stop()
        _isSpeaking.value = false
        _currentWord.value = null
    }

    fun shutdown() {
        tts?.shutdown()
        tts = null
        isInitialized = false
        _isAvailable.value = false
    }
}
