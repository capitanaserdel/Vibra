package com.example.music

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.provider.MediaStore
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.example.vibra/file_management"
    private val DELETE_REQUEST_CODE = 1001
    private var pendingDeleteResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setRingtone" -> {
                    val path = call.argument<String>("path")
                    val title = call.argument<String>("title")
                    if (path != null && title != null) {
                        setRingtone(path, title, result)
                    } else {
                        result.error("INVALID_ARGS", "Path or title is null", null)
                    }
                }
                "deleteFile" -> {
                    val id = call.argument<Int>("id")?.toLong()
                    val path = call.argument<String>("path")
                    if (id != null) {
                        deleteFileById(id, path, result)
                    } else {
                        result.error("INVALID_ARGS", "ID is null", null)
                    }
                }
                "openManageStorageSettings" -> {
                    openManageStorageSettings(result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setRingtone(path: String, title: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.System.canWrite(this)) {
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
                result.error("PERMISSION_DENIED", "Write settings permission required", null)
                return
            }
        }

        try {
            val file = File(path)
            val values = ContentValues()
            values.put(MediaStore.MediaColumns.DATA, file.absolutePath)
            values.put(MediaStore.MediaColumns.TITLE, title)
            values.put(MediaStore.MediaColumns.MIME_TYPE, "audio/mp3")
            values.put(MediaStore.Audio.Media.IS_RINGTONE, true)
            values.put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
            values.put(MediaStore.Audio.Media.IS_ALARM, false)
            values.put(MediaStore.Audio.Media.IS_MUSIC, false)

            val uri = MediaStore.Audio.Media.getContentUriForPath(file.absolutePath)
            this.contentResolver.delete(uri!!, "${MediaStore.MediaColumns.DATA}=?", arrayOf(file.absolutePath))
            val newUri = this.contentResolver.insert(uri, values)

            RingtoneManager.setActualDefaultRingtoneUri(
                this,
                RingtoneManager.TYPE_RINGTONE,
                newUri
            )
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun deleteFileById(id: Long, path: String?, result: MethodChannel.Result) {
        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // Check if we have MANAGE_EXTERNAL_STORAGE
                val hasManageStorage = android.os.Environment.isExternalStorageManager()
                if (hasManageStorage && path != null) {
                    val file = File(path)
                    if (file.exists() && file.delete()) {
                        // Also remove from MediaStore to avoid stale entry
                        contentResolver.delete(uri, null, null)
                        result.success(true)
                        return
                    }
                }

                // Fallback to Scoped Storage request
                val uris = listOf(uri)
                val pendingIntent = MediaStore.createDeleteRequest(contentResolver, uris)
                pendingDeleteResult = result
                startIntentSenderForResult(pendingIntent.intentSender, DELETE_REQUEST_CODE, null, 0, 0, 0)
            } else {
                val deleted = contentResolver.delete(uri, null, null)
                if (deleted > 0) result.success(true) else result.error("DELETE_FAILED", "Could not delete file", null)
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
        }
    }

    private fun openManageStorageSettings(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
                result.success(true)
            } catch (e: Exception) {
                val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                startActivity(intent)
                result.success(true)
            }
        } else {
            result.error("NOT_SUPPORTED", "Manage storage not supported on this Android version", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == DELETE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                pendingDeleteResult?.success(true)
            } else {
                pendingDeleteResult?.error("CANCELLED", "User cancelled deletion", null)
            }
            pendingDeleteResult = null
        }
    }
}
