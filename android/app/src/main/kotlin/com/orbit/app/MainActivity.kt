package com.orbit.app

import android.Manifest
import android.app.ActivityManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "orbit/voip"
	private val requestCodeVoipPermissions = 1194
	private var audioFocusRequest: AudioFocusRequest? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				handleVoipMethod(call, result)
			}
	}

	private fun handleVoipMethod(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"getManufacturer" -> {
				result.success(Build.MANUFACTURER.lowercase())
			}

			"isIgnoringBatteryOptimizations" -> {
				result.success(isIgnoringBatteryOptimizations())
			}

			"openBatteryOptimizationSettings" -> {
				result.success(openBatteryOptimizationSettings())
			}

			"openOemAutostartSettings" -> {
				result.success(openOemAutostartSettings())
			}

			"ensureVoipRuntimeSetup" -> {
				ensureVoipRuntimeSetup()
				result.success(true)
			}

			"startVoipForeground" -> {
				val title = call.argument<String>("title") ?: "Llamada Orbit en curso"
				startVoipForegroundService(title)
				result.success(true)
			}

			"stopVoipForeground" -> {
				stopService(Intent(this, OrbitVoipForegroundService::class.java))
				result.success(true)
			}

			"setVoipAudioMode" -> {
				val speakerOn = call.argument<Boolean>("speakerOn") ?: false
				setVoipAudioMode(speakerOn)
				result.success(true)
			}

			"setNormalAudioMode" -> {
				setNormalAudioMode()
				result.success(true)
			}

			"getVoipCapabilityReport" -> {
				result.success(
					mapOf(
						"sdkInt" to Build.VERSION.SDK_INT,
						"manufacturer" to Build.MANUFACTURER,
						"model" to Build.MODEL,
						"isIgnoringBatteryOptimizations" to isIgnoringBatteryOptimizations(),
						"bluetoothEnabled" to (BluetoothAdapter.getDefaultAdapter()?.isEnabled == true),
						"foregroundServiceRunning" to isVoipForegroundRunning(),
					),
				)
			}

			else -> result.notImplemented()
		}
	}

	private fun ensureVoipRuntimeSetup() {
		val pendingPermissions = mutableListOf<String>()
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
				pendingPermissions.add(Manifest.permission.POST_NOTIFICATIONS)
			}
		}
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
			if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
				pendingPermissions.add(Manifest.permission.BLUETOOTH_CONNECT)
			}
		}
		if (pendingPermissions.isNotEmpty()) {
			ActivityCompat.requestPermissions(this, pendingPermissions.toTypedArray(), requestCodeVoipPermissions)
		}
	}

	private fun isIgnoringBatteryOptimizations(): Boolean {
		val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
		return pm.isIgnoringBatteryOptimizations(packageName)
	}

	private fun openBatteryOptimizationSettings(): Boolean {
		return try {
			if (!isIgnoringBatteryOptimizations()) {
				val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
					.setData(Uri.parse("package:$packageName"))
					.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				startActivity(intent)
			} else {
				val intent = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
					.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				startActivity(intent)
			}
			true
		} catch (_: Exception) {
			false
		}
	}

	private fun openOemAutostartSettings(): Boolean {
		val manufacturer = Build.MANUFACTURER.lowercase()
		val intents = when {
			manufacturer.contains("xiaomi") -> listOf(
				Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
			)

			manufacturer.contains("huawei") -> listOf(
				Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
			)

			manufacturer.contains("samsung") -> listOf(
				Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
			)

			manufacturer.contains("oppo") -> listOf(
				Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
			)

			manufacturer.contains("vivo") -> listOf(
				Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
			)

			manufacturer.contains("oneplus") -> listOf(
				Intent().setComponent(ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")),
			)

			else -> listOf(
				Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
					.setData(Uri.parse("package:$packageName")),
			)
		}

		intents.forEach { baseIntent ->
			try {
				baseIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
				startActivity(baseIntent)
				return true
			} catch (_: Exception) {
			}
		}
		return false
	}

	private fun setVoipAudioMode(speakerOn: Boolean) {
		val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			val req = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
				.setAudioAttributes(
					AudioAttributes.Builder()
						.setUsage(AudioAttributes.USAGE_VOICE_COMMUNICATION)
						.setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
						.build(),
				)
				.build()
			audioFocusRequest = req
			am.requestAudioFocus(req)
		} else {
			@Suppress("DEPRECATION")
			am.requestAudioFocus(
				null,
				AudioManager.STREAM_VOICE_CALL,
				AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE,
			)
		}
		am.mode = AudioManager.MODE_IN_COMMUNICATION
		am.isSpeakerphoneOn = speakerOn
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
			ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
		) {
			try {
				am.startBluetoothSco()
				am.isBluetoothScoOn = true
			} catch (_: Exception) {
			}
		}
	}

	private fun setNormalAudioMode() {
		val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			audioFocusRequest?.let { am.abandonAudioFocusRequest(it) }
			audioFocusRequest = null
		} else {
			@Suppress("DEPRECATION")
			am.abandonAudioFocus(null)
		}
		try {
			am.stopBluetoothSco()
		} catch (_: Exception) {
		}
		am.isBluetoothScoOn = false
		am.mode = AudioManager.MODE_NORMAL
	}

	private fun startVoipForegroundService(title: String) {
		val intent = Intent(this, OrbitVoipForegroundService::class.java)
			.setAction(OrbitVoipForegroundService.ACTION_START)
			.putExtra(OrbitVoipForegroundService.EXTRA_TITLE, title)
		ContextCompat.startForegroundService(this, intent)
	}

	private fun isVoipForegroundRunning(): Boolean {
		val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
		@Suppress("DEPRECATION")
		return am.getRunningServices(Int.MAX_VALUE).any {
			it.service.className == OrbitVoipForegroundService::class.java.name
		}
	}
}

class OrbitVoipForegroundService : Service() {
	override fun onBind(intent: Intent?): IBinder? = null

	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		when (intent?.action) {
			ACTION_STOP -> {
				stopForeground(STOP_FOREGROUND_REMOVE)
				stopSelf()
			}

			else -> {
				val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Llamada Orbit en curso"
				ensureChannel()
				val notification = buildNotification(title)
				startAsVoipForeground(notification)
			}
		}
		return START_STICKY
	}

	private fun startAsVoipForeground(notification: Notification) {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
			startForeground(
				NOTIFICATION_ID,
				notification,
				ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL or
					ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
					ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
					ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE or
					ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
			)
		} else {
			startForeground(NOTIFICATION_ID, notification)
		}
	}

	private fun ensureChannel() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
		val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
		val channel = NotificationChannel(
			CHANNEL_ID,
			"Orbit VoIP",
			NotificationManager.IMPORTANCE_LOW,
		).apply {
			description = "Llamadas activas y reconexión en segundo plano"
			lockscreenVisibility = Notification.VISIBILITY_PUBLIC
		}
		nm.createNotificationChannel(channel)
	}

	private fun buildNotification(title: String): Notification {
		val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
			?: Intent(this, MainActivity::class.java).apply {
				addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
			}
		val contentIntent = PendingIntent.getActivity(
			this,
			0,
			launchIntent,
			PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
		)
		return NotificationCompat.Builder(this, CHANNEL_ID)
			.setSmallIcon(R.mipmap.ic_launcher)
			.setContentTitle(title)
			.setContentText("Orbit mantiene la llamada estable en background")
			.setOngoing(true)
			.setCategory(NotificationCompat.CATEGORY_CALL)
			.setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
			.setPriority(NotificationCompat.PRIORITY_HIGH)
			.setContentIntent(contentIntent)
			.build()
	}

	companion object {
		const val CHANNEL_ID = "orbit_voip_call"
		const val NOTIFICATION_ID = 7701
		const val ACTION_START = "orbit.voip.START"
		const val ACTION_STOP = "orbit.voip.STOP"
		const val EXTRA_TITLE = "title"
	}
}
