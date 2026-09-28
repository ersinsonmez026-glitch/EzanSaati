package com.ezansaati.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // Manyetik kuzey ile gerçek kuzey arasındaki fark (derece)
    private var declination = 0f

    // Dua Çemberi: telefonun kişi seçicisinden dönecek sonuç
    private var pendingContact: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "ezan_saati/compass_config").setMethodCallHandler { call, result ->
            if (call.method == "setLocation") {
                val lat = call.argument<Double>("lat") ?: 0.0
                val lng = call.argument<Double>("lng") ?: 0.0
                declination = GeomagneticField(
                    lat.toFloat(), lng.toFloat(), 0f, System.currentTimeMillis()
                ).declination
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        EventChannel(messenger, "ezan_saati/compass").setStreamHandler(CompassStream())

        // Rehber izni istemeden, telefonun kendi kişi seçicisiyle tek kişi seçilir.
        MethodChannel(messenger, "ezan_saati/contacts").setMethodCallHandler { call, result ->
            if (call.method != "pick") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            pendingContact?.success(null)
            pendingContact = result
            try {
                val intent = Intent(Intent.ACTION_PICK, ContactsContract.CommonDataKinds.Phone.CONTENT_URI)
                startActivityForResult(intent, PICK_CONTACT)
            } catch (e: Exception) {
                pendingContact = null
                result.error("NO_PICKER", "Kişi seçici açılamadı.", null)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_CONTACT) return
        val result = pendingContact ?: return
        pendingContact = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            contentResolver.query(
                uri,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                null, null, null
            )?.use { c ->
                if (c.moveToFirst()) {
                    result.success(mapOf("name" to (c.getString(0) ?: ""), "phone" to (c.getString(1) ?: "")))
                    return
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("READ_FAILED", "Kişi okunamadı.", null)
        }
    }

    companion object {
        private const val PICK_CONTACT = 4711
    }

    /** Telefonun yön sensörünü Flutter'a akıtır: [yön (0-360), doğruluk (0-3)] */
    private inner class CompassStream : EventChannel.StreamHandler, SensorEventListener {
        private var sink: EventChannel.EventSink? = null
        private var sensorManager: SensorManager? = null
        private val rotation = FloatArray(9)
        private val orientation = FloatArray(3)
        private var accuracy = SensorManager.SENSOR_STATUS_ACCURACY_HIGH

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            sink = events
            val sm = getSystemService(Context.SENSOR_SERVICE) as SensorManager
            sensorManager = sm
            val rotationSensor = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
                ?: sm.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
            if (rotationSensor == null) {
                events?.error("NO_SENSOR", "Bu telefonda pusula sensörü bulunmuyor.", null)
                return
            }
            sm.registerListener(this, rotationSensor, SensorManager.SENSOR_DELAY_UI)
            // Sadece kalibrasyon durumunu öğrenmek için
            sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)?.let {
                sm.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
            }
        }

        override fun onCancel(arguments: Any?) {
            sensorManager?.unregisterListener(this)
            sensorManager = null
            sink = null
        }

        override fun onSensorChanged(event: SensorEvent?) {
            if (event == null) return
            val type = event.sensor.type
            if (type != Sensor.TYPE_ROTATION_VECTOR && type != Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR) return
            SensorManager.getRotationMatrixFromVector(rotation, event.values)
            SensorManager.getOrientation(rotation, orientation)
            var heading = Math.toDegrees(orientation[0].toDouble()) + declination
            heading = (heading + 360.0) % 360.0
            sink?.success(listOf(heading, accuracy))
        }

        override fun onAccuracyChanged(sensor: Sensor?, newAccuracy: Int) {
            if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD) {
                accuracy = newAccuracy
            }
        }
    }
}
