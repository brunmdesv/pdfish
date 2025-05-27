package com.example.pdfish

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pdfish/file_intent"
    private var initialFilePath: String? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInitialFilePath") {
                result.success(initialFilePath)
            } else {
                result.notImplemented()
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent) {
        val action = intent.action
        val type = intent.type
        
        if (Intent.ACTION_VIEW == action && type?.startsWith("application/pdf") == true) {
            val uri = intent.data
            if (uri != null) {
                try {
                    // Copia o arquivo para o cache e guarda o caminho
                    initialFilePath = copyFileToCache(uri)
                    Log.d("PDFish", "Arquivo PDF recebido: $initialFilePath")
                } catch (e: Exception) {
                    Log.e("PDFish", "Erro ao processar arquivo PDF: ${e.message}")
                }
            }
        }
    }
    
    private fun copyFileToCache(uri: Uri): String? {
        val inputStream = contentResolver.openInputStream(uri) ?: return null
        
        // Tenta obter o nome do arquivo a partir do URI
        var fileName = ""
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val displayNameIndex = cursor.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                if (displayNameIndex != -1) {
                    fileName = cursor.getString(displayNameIndex)
                }
            }
        }
        
        // Se não conseguiu obter o nome, gera um nome único
        if (fileName.isEmpty()) {
            fileName = "pdf_${System.currentTimeMillis()}.pdf"
        }
        
        // Cria o arquivo no diretório de cache
        val cacheDir = cacheDir
        val file = File(cacheDir, fileName)
        
        // Copia o conteúdo do URI para o arquivo
        FileOutputStream(file).use { outputStream ->
            val buffer = ByteArray(4 * 1024) // 4KB buffer
            var read: Int
            while (inputStream.read(buffer).also { read = it } != -1) {
                outputStream.write(buffer, 0, read)
            }
            outputStream.flush()
        }
        
        inputStream.close()
        return file.absolutePath
    }
    
    // Método removido conforme solicitado pelo usuário
}
