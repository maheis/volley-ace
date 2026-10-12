package be.heister.volleyace

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

private const val vaceChannelName = "be.heister.volleyace/vace"
private const val vaceMimeType = "application/vnd.volleyace"

class MainActivity : FlutterActivity() {
	private var pendingVaceUri: Uri? = null
	private var vaceChannel: MethodChannel? = null

	override fun onCreate(savedInstanceState: Bundle?) {
		val launchIntent = intent
		pendingVaceUri = launchIntent?.data?.takeIf { uri ->
			uri.lastPathSegment?.endsWith(".vace", ignoreCase = true) == true ||
				launchIntent.type == vaceMimeType
		}
		super.onCreate(savedInstanceState)
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		vaceChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			vaceChannelName,
		).also { channel ->
			channel.setMethodCallHandler { call, result ->
				if (call.method != "takeInitialVaceFile") {
					result.notImplemented()
					return@setMethodCallHandler
				}
				val uri = pendingVaceUri ?: intent?.data?.takeIf(::isVaceUri)
				pendingVaceUri = null
				if (uri == null) {
					result.success(null)
					return@setMethodCallHandler
				}
				try {
					result.success(readVacePayload(uri))
				} catch (error: Exception) {
					result.error("vace_read_failed", error.message, null)
				}
			}
		}
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		val uri = intent.data?.takeIf(::isVaceUri) ?: return
		pendingVaceUri = uri
		val channel = vaceChannel ?: return
		try {
			val payload = readVacePayload(uri)
			pendingVaceUri = null
			channel.invokeMethod("openVaceFile", payload)
		} catch (_: Exception) {
			// Dart will show an import error when the pending file is requested.
		}
	}

	private fun isVaceUri(uri: Uri): Boolean =
		uri.lastPathSegment?.endsWith(".vace", ignoreCase = true) == true ||
			contentResolver.getType(uri) == vaceMimeType

	private fun readVacePayload(uri: Uri): Map<String, Any> {
		val fileName = contentResolver.query(
			uri,
			arrayOf(OpenableColumns.DISPLAY_NAME),
			null,
			null,
			null,
		)?.use { cursor: Cursor ->
			if (cursor.moveToFirst()) {
				cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
			} else {
				null
			}
		} ?: uri.lastPathSegment ?: "volleyace.vace"
		val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
			?: if (uri.scheme == "file") File(uri.path!!).readBytes() else null
			?: throw IllegalArgumentException("Dateiinhalt nicht verfügbar")
		return mapOf("name" to fileName, "content" to bytes)
	}
}