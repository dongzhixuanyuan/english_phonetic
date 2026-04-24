package com.liudong.bookread.ui.components

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.exifinterface.media.ExifInterface
import java.io.InputStream

fun getBitmapFromUri(context: Context, uri: Uri): Bitmap? {
    return try {
        context.contentResolver.openInputStream(uri)?.use { inputStream ->
            val bitmap = BitmapFactory.decodeStream(inputStream)
            fixImageOrientation(context, uri, bitmap)
        }
    } catch (e: Exception) {
        e.printStackTrace()
        null
    }
}

private fun fixImageOrientation(context: Context, uri: Uri, bitmap: Bitmap?): Bitmap? {
    bitmap ?: return null
    val inputStream: InputStream? = context.contentResolver.openInputStream(uri)
    inputStream?.use {
        val exif = ExifInterface(it)
        val orientation = exif.getAttributeInt(
            ExifInterface.TAG_ORIENTATION,
            ExifInterface.ORIENTATION_NORMAL
        )
        val rotation = when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90
            ExifInterface.ORIENTATION_ROTATE_180 -> 180
            ExifInterface.ORIENTATION_ROTATE_270 -> 270
            else -> 0
        }
        return if (rotation != 0) {
            val matrix = Matrix()
            matrix.postRotate(rotation.toFloat())
            Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        } else {
            bitmap
        }
    }
    return bitmap
}
