package com.example.music

import android.app.Activity
import android.app.RecoverableSecurityException
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.media.RingtoneManager
import android.media.audiofx.Equalizer
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
    private var equalizer: Equalizer? = null

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
                    val id = call.argument<Number>("id")?.toLong()
                    val path = call.argument<String>("path")
                    val uriStr = call.argument<String>("uri")
                    if (id != null) {
                        deleteFileById(id, path, uriStr, result)
                    } else {
                        result.error("INVALID_ARGS", "ID is null", null)
                    }
                }
                "openManageStorageSettings" -> {
                    openManageStorageSettings(result)
                }
                "openEqualizer" -> {
                    val audioSessionId = call.argument<Int>("audioSessionId") ?: 0
                    openEqualizer(audioSessionId, result)
                }
                "equalizerInit" -> {
                    val sessionId = call.argument<Int>("audioSessionId") ?: 0
                    equalizerInit(sessionId, result)
                }
                "equalizerSetBandLevel" -> {
                    val band = call.argument<Int>("band") ?: 0
                    val level = call.argument<Int>("level") ?: 0
                    equalizerSetBandLevel(band, level, result)
                }
                "equalizerSetEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    equalizerSetEnabled(enabled, result)
                }
                "equalizerRelease" -> {
                    equalizerRelease(result)
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

    private fun deleteFileById(id: Long, path: String?, uriStr: String?, result: MethodChannel.Result) {
        val uri = if (uriStr != null) {
            Uri.parse(uriStr)
        } else {
            val volumeName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.VOLUME_EXTERNAL_PRIMARY
            } else {
                "external"
            }
            val baseUri = MediaStore.Audio.Media.getContentUri(volumeName)
            ContentUris.withAppendedId(baseUri, id)
        }

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
                try {
                    val deleted = contentResolver.delete(uri, null, null)
                    if (deleted > 0) {
                        result.success(true)
                    } else {
                        if (path != null) {
                            val file = File(path)
                            if (file.exists() && file.delete()) {
                                result.success(true)
                            } else {
                                result.error("DELETE_FAILED", "Could not delete file", null)
                            }
                        } else {
                            result.error("DELETE_FAILED", "Could not delete file", null)
                        }
                    }
                } catch (securityException: SecurityException) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && securityException is RecoverableSecurityException) {
                        val pendingIntent = securityException.userAction.actionIntent
                        pendingDeleteResult = result
                        startIntentSenderForResult(pendingIntent.intentSender, DELETE_REQUEST_CODE, null, 0, 0, 0)
                    } else {
                        result.error("PERMISSION_DENIED", securityException.message, null)
                    }
                }
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

    private fun equalizerInit(sessionId: Int, result: MethodChannel.Result) {
        try {
            equalizer?.release()
            equalizer = Equalizer(0, sessionId)
            equalizer!!.enabled = true

            val numBands = equalizer!!.numberOfBands.toInt()
            val levelRange = equalizer!!.bandLevelRange
            val minLevel = levelRange[0].toInt()
            val maxLevel = levelRange[1].toInt()

            val bands = mutableListOf<Map<String, Any>>()
            for (i in 0 until numBands) {
                val freqRange = equalizer!!.getBandFreqRange(i.toShort())
                val centerFreq = equalizer!!.getCenterFreq(i.toShort())
                val level = equalizer!!.getBandLevel(i.toShort()).toInt()
                bands.add(mapOf(
                    "index" to i,
                    "minFreq" to freqRange[0],
                    "maxFreq" to freqRange[1],
                    "centerFreq" to centerFreq,
                    "level" to level
                ))
            }

            result.success(mapOf(
                "numBands" to numBands,
                "minLevel" to minLevel,
                "maxLevel" to maxLevel,
                "bands" to bands,
                "enabled" to (equalizer?.enabled ?: false)
            ))
        } catch (e: Exception) {
            result.error("EQ_ERROR", e.message, null)
        }
    }

    private fun equalizerSetBandLevel(band: Int, level: Int, result: MethodChannel.Result) {
        try {
            equalizer?.setBandLevel(band.toShort(), level.toShort())
            result.success(true)
        } catch (e: Exception) {
            result.error("EQ_ERROR", e.message, null)
        }
    }

    private fun equalizerSetEnabled(enabled: Boolean, result: MethodChannel.Result) {
        try {
            equalizer?.enabled = enabled
            result.success(true)
        } catch (e: Exception) {
            result.error("EQ_ERROR", e.message, null)
        }
    }

    private fun equalizerRelease(result: MethodChannel.Result) {
        try {
            equalizer?.release()
            equalizer = null
            result.success(true)
        } catch (e: Exception) {
            result.error("EQ_ERROR", e.message, null)
        }
    }

    private fun openEqualizer(audioSessionId: Int, result: MethodChannel.Result) {
        try {
            val intent = Intent(android.media.audiofx.AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL)
            intent.putExtra(android.media.audiofx.AudioEffect.EXTRA_AUDIO_SESSION, audioSessionId)
            intent.putExtra(android.media.audiofx.AudioEffect.EXTRA_CONTENT_TYPE, android.media.audiofx.AudioEffect.CONTENT_TYPE_MUSIC)
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                result.success(true)
            } else {
                result.error("NOT_AVAILABLE", "No equalizer app found on this device", null)
            }
        } catch (e: Exception) {
            result.error("ERROR", e.message, null)
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
