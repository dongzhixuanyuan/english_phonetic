package com.liudong.bookread.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class WordAnnotation(
    val id: String = UUID.randomUUID().toString(),
    var word: String,
    var phonetic: String,
    var normalizedX: Double,
    var normalizedY: Double,
    var normalizedWidth: Double,
    var normalizedHeight: Double
)

@Serializable
data class TextbookPage(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var imagePath: String,
    var order: Int,
    var annotations: List<WordAnnotation> = emptyList()
)

@Serializable
data class TextbookUnit(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var order: Int,
    var pages: List<TextbookPage> = emptyList()
)

@Serializable
data class Textbook(
    val id: String = UUID.randomUUID().toString(),
    var name: String,
    var coverImagePath: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    var units: List<TextbookUnit> = emptyList()
)
