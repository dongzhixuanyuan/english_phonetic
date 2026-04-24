package com.liudong.bookread.service

import android.graphics.Bitmap
import android.graphics.Rect
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

object OCRService {
    data class OCRResult(
        val text: String,
        val boundingBox: Rect
    )

    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    fun recognizeText(bitmap: Bitmap): Flow<List<OCRResult>> = flow {
        val image = InputImage.fromBitmap(bitmap, 0)
        val result = recognizer.process(image).await()
        val results = mutableListOf<OCRResult>()

        for (block in result.textBlocks) {
            for (line in block.lines) {
                val text = line.text.trim()
                if (!shouldKeep(text)) continue

                val words = text.split(Regex("\\s+")).filter { it.isNotEmpty() }
                if (words.size > 1) {
                    for (element in line.elements) {
                        val word = element.text.trim()
                        if (shouldKeep(word)) {
                            results.add(OCRResult(word, element.boundingBox ?: line.boundingBox!!))
                        }
                    }
                } else {
                    results.add(OCRResult(text, line.boundingBox!!))
                }
            }
        }
        emit(results)
    }.flowOn(Dispatchers.IO)

    private fun shouldKeep(text: String): Boolean {
        if (text.all { it.isDigit() }) return false
        if (text.length < 2 && text != "I" && text != "a") return false
        val letters = text.filter { it.isLetter() }
        return letters.isNotEmpty()
    }

    private suspend fun <T> com.google.android.gms.tasks.Task<T>.await(): T =
        suspendCancellableCoroutine { cont ->
            addOnSuccessListener { cont.resume(it) }
            addOnFailureListener { cont.resumeWithException(it) }
        }
}
