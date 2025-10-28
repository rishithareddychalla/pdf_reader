package com.example.pdf_reader

import android.content.ContentResolver
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "pdf_reader/file_handler"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "copyContentUri" -> {
                    val contentUri = call.argument<String>("contentUri")
                    val destinationPath = call.argument<String>("destinationPath")
                    
                    if (contentUri != null && destinationPath != null) {
                        try {
                            val success = copyContentUriToFile(contentUri, destinationPath)
                            result.success(success)
                        } catch (e: Exception) {
                            result.error("COPY_ERROR", "Failed to copy file: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing contentUri or destinationPath", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun copyContentUriToFile(contentUri: String, destinationPath: String): Boolean {
        return try {
            val uri = Uri.parse(contentUri)
            val contentResolver: ContentResolver = contentResolver
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            
            if (inputStream != null) {
                val outputFile = File(destinationPath)
                outputFile.parentFile?.mkdirs()
                
                val outputStream = FileOutputStream(outputFile)
                
                inputStream.use { input ->
                    outputStream.use { output ->
                        input.copyTo(output)
                    }
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}
