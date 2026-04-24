package com.liudong.bookread.viewmodel

import android.app.Application
import android.graphics.Bitmap
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.liudong.bookread.model.Textbook
import com.liudong.bookread.model.TextbookPage
import com.liudong.bookread.model.TextbookUnit
import com.liudong.bookread.model.WordAnnotation
import com.liudong.bookread.service.DataStoreService
import com.liudong.bookread.service.OCRService
import com.liudong.bookread.service.PhoneticDictionaryService
import com.liudong.bookread.service.SpeechService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.util.UUID

class TextbookViewModel(application: Application) : AndroidViewModel(application) {
    private val app = getApplication<Application>()
    private val context get() = app.applicationContext

    private val _textbooks = MutableStateFlow<List<Textbook>>(emptyList())
    val textbooks: StateFlow<List<Textbook>> = _textbooks.asStateFlow()

    private val _isProcessing = MutableStateFlow(false)
    val isProcessing: StateFlow<Boolean> = _isProcessing.asStateFlow()

    private val _processingProgress = MutableStateFlow("")
    val processingProgress: StateFlow<String> = _processingProgress.asStateFlow()

    init {
        viewModelScope.launch {
            loadTextbooks()
            setupSamplePages()
        }
        PhoneticDictionaryService.loadDictionary(context)
        SpeechService.initialize(context)
    }

    private suspend fun loadTextbooks() {
        _textbooks.value = DataStoreService.loadTextbooks(context)
    }

    private fun saveTextbooks() {
        viewModelScope.launch {
            DataStoreService.saveTextbooks(context, _textbooks.value)
        }
    }

    private fun setupSamplePages() {
        if (_textbooks.value.any { it.name == "示例课本" }) return
        val sampleUnit = TextbookUnit(name = "Unit 1 Hello", order = 0)
        val sampleTextbook = Textbook(name = "示例课本", units = listOf(sampleUnit))
        _textbooks.value = listOf(sampleTextbook) + _textbooks.value
        saveTextbooks()
    }

    fun addTextbook(name: String): Textbook {
        val textbook = Textbook(name = name)
        _textbooks.value = _textbooks.value + textbook
        saveTextbooks()
        return textbook
    }

    fun deleteTextbook(textbook: Textbook) {
        textbook.units.flatMap { it.pages }.forEach { page ->
            DataStoreService.deleteImage(context, page.imagePath)
        }
        _textbooks.value = _textbooks.value.filter { it.id != textbook.id }
        saveTextbooks()
    }

    fun addPage(
        textbookId: String,
        unitId: String,
        bitmap: Bitmap,
        pageName: String,
        onComplete: (TextbookPage?) -> Unit
    ) {
        viewModelScope.launch {
            _isProcessing.value = true
            _processingProgress.value = "正在识别文字..."

            val pageId = UUID.randomUUID().toString()
            val imageFilename = DataStoreService.saveImage(context, bitmap, pageId)
                ?: run {
                    _isProcessing.value = false
                    onComplete(null)
                    return@launch
                }

            val ocrResults = OCRService.recognizeText(bitmap).first()

            _processingProgress.value = "正在生成音标..."
            val annotations = ocrResults.map { result ->
                WordAnnotation(
                    word = result.text,
                    phonetic = PhoneticDictionaryService.lookup(result.text) ?: "",
                    normalizedX = result.boundingBox.left.toDouble() / bitmap.width,
                    normalizedY = 1.0 - (result.boundingBox.bottom.toDouble() / bitmap.height),
                    normalizedWidth = result.boundingBox.width().toDouble() / bitmap.width,
                    normalizedHeight = result.boundingBox.height().toDouble() / bitmap.height
                )
            }

            val page = TextbookPage(
                id = pageId,
                name = pageName,
                imagePath = imageFilename,
                order = 0,
                annotations = annotations
            )

            val updated = _textbooks.value.map { tb ->
                if (tb.id == textbookId) {
                    tb.copy(units = tb.units.map { unit ->
                        if (unit.id == unitId) unit.copy(pages = unit.pages + page) else unit
                    })
                } else tb
            }
            _textbooks.value = updated
            saveTextbooks()

            _isProcessing.value = false
            _processingProgress.value = ""
            onComplete(page)
        }
    }

    fun updateAnnotations(textbookId: String, unitId: String, pageId: String, annotations: List<WordAnnotation>) {
        val updated = _textbooks.value.map { tb ->
            if (tb.id == textbookId) {
                tb.copy(units = tb.units.map { unit ->
                    if (unit.id == unitId) {
                        unit.copy(pages = unit.pages.map { p ->
                            if (p.id == pageId) p.copy(annotations = annotations) else p
                        })
                    } else unit
                })
            } else tb
        }
        _textbooks.value = updated
        saveTextbooks()
    }

    fun deletePage(textbookId: String, unitId: String, page: TextbookPage) {
        DataStoreService.deleteImage(context, page.imagePath)
        val updated = _textbooks.value.map { tb ->
            if (tb.id == textbookId) {
                tb.copy(units = tb.units.map { unit ->
                    if (unit.id == unitId) unit.copy(pages = unit.pages.filter { it.id != page.id })
                    else unit
                })
            } else tb
        }
        _textbooks.value = updated
        saveTextbooks()
    }

    fun renamePage(textbookId: String, unitId: String, page: TextbookPage, newName: String) {
        val updated = _textbooks.value.map { tb ->
            if (tb.id == textbookId) {
                tb.copy(units = tb.units.map { unit ->
                    if (unit.id == unitId) {
                        unit.copy(pages = unit.pages.map { p ->
                            if (p.id == page.id) p.copy(name = newName) else p
                        })
                    } else unit
                })
            } else tb
        }
        _textbooks.value = updated
        saveTextbooks()
    }

    fun addUnit(textbookId: String, name: String): TextbookUnit? {
        val textbook = _textbooks.value.find { it.id == textbookId } ?: return null
        val order = textbook.units.size
        val unit = TextbookUnit(name = name, order = order)
        val updated = _textbooks.value.map { tb ->
            if (tb.id == textbookId) tb.copy(units = tb.units + unit) else tb
        }
        _textbooks.value = updated
        saveTextbooks()
        return unit
    }

    fun reprocessPage(textbookId: String, unitId: String, page: TextbookPage, bitmap: Bitmap, onComplete: (List<WordAnnotation>) -> Unit) {
        viewModelScope.launch {
            _isProcessing.value = true
            _processingProgress.value = "重新识别中..."

            val ocrResults = OCRService.recognizeText(bitmap).first()
            val annotations = ocrResults.map { result ->
                WordAnnotation(
                    word = result.text,
                    phonetic = PhoneticDictionaryService.lookup(result.text) ?: "",
                    normalizedX = result.boundingBox.left.toDouble() / bitmap.width,
                    normalizedY = 1.0 - (result.boundingBox.bottom.toDouble() / bitmap.height),
                    normalizedWidth = result.boundingBox.width().toDouble() / bitmap.width,
                    normalizedHeight = result.boundingBox.height().toDouble() / bitmap.height
                )
            }

            val updated = _textbooks.value.map { tb ->
                if (tb.id == textbookId) {
                    tb.copy(units = tb.units.map { u ->
                        if (u.id == unitId) {
                            u.copy(pages = u.pages.map { p ->
                                if (p.id == page.id) p.copy(annotations = annotations) else p
                            })
                        } else u
                    })
                } else tb
            }
            _textbooks.value = updated
            saveTextbooks()

            _isProcessing.value = false
            _processingProgress.value = ""
            onComplete(annotations)
        }
    }
}
