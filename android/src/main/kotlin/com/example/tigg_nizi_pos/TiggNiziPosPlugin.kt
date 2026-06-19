package com.example.tigg_nizi_pos

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class TiggNiziPosPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var appContext: Context? = null
    private var serialPort: UsbSerialPort? = null
    private var connectionEventSink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    private val ACTION_USB_PERMISSION = "com.example.tigg_nizi_pos.USB_PERMISSION"

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    val granted = intent.getBooleanExtra(
                        UsbManager.EXTRA_PERMISSION_GRANTED, false
                    )
                    if (granted) {
                        openDevice()
                    } else {
                        connectionEventSink?.success(mapOf("state" to "permissionDenied"))
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    tryConnect()
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    safeClosePort()
                    connectionEventSink?.success(mapOf("state" to "disconnected"))
                }
            }
        }
    }

    // ── FlutterPlugin ─────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext

        methodChannel = MethodChannel(binding.binaryMessenger, "tigg_nizi_pos")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, "tigg_nizi_pos/connection")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                connectionEventSink = events
                registerReceiver()
            }
            override fun onCancel(arguments: Any?) {
                connectionEventSink = null
                unregisterReceiver()
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        safeClosePort()
        unregisterReceiver()
        appContext = null
    }

    // ── MethodCallHandler ─────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connect" -> handleConnect(result)
            "disconnect" -> {
                safeClosePort()
                result.success(true)
            }
            "isConnected" -> result.success(serialPort != null)
            "sendCommand" -> {
                val command = call.argument<String>("command")
                    ?: return result.error("INVALID_ARG", "command is required", null)
                handleSendCommand(command, result)
            }
            "displayRealTimeImage" -> {
                val bytes = call.argument<ByteArray>("jpegBytes")
                    ?: return result.error("INVALID_ARG", "jpegBytes is required", null)
                handleDisplayRealTimeImage(bytes, result)
            }
            else -> result.notImplemented()
        }
    }

    // ── Connection helpers ────────────────────────────────────────────────────

    private fun handleConnect(result: Result) {
        val ctx = appContext
            ?: return result.error("NO_CONTEXT", "Application context unavailable", null)
        val manager = ctx.getSystemService(Context.USB_SERVICE) as UsbManager
        val drivers = UsbSerialProber.getDefaultProber().findAllDrivers(manager)

        if (drivers.isEmpty()) {
            return result.success(false)
        }

        val driver = drivers[0]
        if (!manager.hasPermission(driver.device)) {
            requestPermission(ctx, manager, driver.device)
            // Connection will complete via usbReceiver → openDevice()
            return result.success(false)
        }

        openDevice()
        result.success(serialPort != null)
    }

    private fun tryConnect() {
        val ctx = appContext ?: return
        val manager = ctx.getSystemService(Context.USB_SERVICE) as UsbManager
        val drivers = UsbSerialProber.getDefaultProber().findAllDrivers(manager)
        if (drivers.isEmpty()) return

        val driver = drivers[0]
        if (!manager.hasPermission(driver.device)) {
            requestPermission(ctx, manager, driver.device)
            return
        }
        openDevice()
    }

    private fun requestPermission(ctx: Context, manager: UsbManager, device: UsbDevice) {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val permissionIntent = PendingIntent.getBroadcast(
            ctx, 0, Intent(ACTION_USB_PERMISSION), flags
        )
        manager.requestPermission(device, permissionIntent)
    }

    private fun openDevice() {
        val ctx = appContext ?: return
        val manager = ctx.getSystemService(Context.USB_SERVICE) as UsbManager
        val drivers = UsbSerialProber.getDefaultProber().findAllDrivers(manager)
        if (drivers.isEmpty()) return

        val driver = drivers[0]
        val connection = manager.openDevice(driver.device) ?: return
        val port = driver.ports[0]

        try {
            port.open(connection)
            port.setParameters(115200, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
            serialPort = port
            connectionEventSink?.success(mapOf("state" to "connected"))
        } catch (e: Exception) {
            connection.close()
            connectionEventSink?.error("OPEN_ERROR", e.message, null)
        }
    }

    private fun safeClosePort() {
        try {
            serialPort?.close()
        } catch (_: Exception) {}
        serialPort = null
    }

    // ── Command sending ───────────────────────────────────────────────────────

    private fun handleSendCommand(command: String, result: Result) {
        val port = serialPort
            ?: return result.error("NOT_CONNECTED", "Device is not connected", null)

        Thread {
            try {
                port.write("$command\n".toByteArray(Charsets.UTF_8), 1000)
                result.success(null)
            } catch (e: Exception) {
                result.error("WRITE_ERROR", e.message, null)
            }
        }.start()
    }

    // ── Real-time image upload ────────────────────────────────────────────────

    private fun handleDisplayRealTimeImage(jpegBytes: ByteArray, result: Result) {
        val port = serialPort
            ?: return result.error("NOT_CONNECTED", "Device is not connected", null)

        Thread {
            try {
                // Flush any stale data sitting in the receive buffer.
                val flush = ByteArray(READ_BUF_SIZE)
                port.read(flush, 100)

                // Step 1+2 — send command + 8-byte header as a single write so
                // the device receives them atomically.
                //   [0..13]  START_RTIMAGE\n  (14 bytes)
                //   [14..17] MAGIC_FRAME       (4 bytes)
                //   [18..21] JPEG length       (4 bytes, little-endian)
                val len = jpegBytes.size
                val cmd = "START_RTIMAGE\n".toByteArray(Charsets.UTF_8)
                val packet = ByteArray(cmd.size + 8)
                cmd.copyInto(packet)
                MAGIC_FRAME.copyInto(packet, destinationOffset = cmd.size)
                packet[cmd.size + 4] = (len and 0xFF).toByte()
                packet[cmd.size + 5] = ((len shr 8) and 0xFF).toByte()
                packet[cmd.size + 6] = ((len shr 16) and 0xFF).toByte()
                packet[cmd.size + 7] = ((len shr 24) and 0xFF).toByte()
                port.write(packet, 2000)

                // Step 3 — wait for 'R' (Ready).
                val ackBuf = ByteArray(READ_BUF_SIZE)
                val ackRead = port.read(ackBuf, 5000)
                val ackStr = if (ackRead > 0) String(ackBuf, 0, ackRead, Charsets.US_ASCII) else ""
                Log.d(TAG, "ACK bytes=$ackRead hex=${ackBuf.take(ackRead).joinToString(" ") { "%02X".format(it) }}")
                if (ackRead <= 0 || !ackStr.contains('R')) {
                    result.error("NO_READY", "Expected 'R', got: ${ackStr.ifEmpty { "<timeout>" }}", null)
                    return@Thread
                }

                // Step 4 — write all JPEG bytes in one call.
                // Log first 4 bytes so we can verify JPEG SOI (FF D8) and
                // confirm 1-channel vs 3-channel (check SOF0 Ncomp byte).
                Log.d(TAG, "Sending ${jpegBytes.size} bytes, header=${jpegBytes.take(4).joinToString(" ") { "%02X".format(it) }}")
                val writeTimeout = maxOf(10_000, jpegBytes.size / 10)
                port.write(jpegBytes, writeTimeout)

                // Step 5 — wait for 'K' (OK) or 'E' (Error).
                val resBuf = ByteArray(READ_BUF_SIZE)
                val resRead = port.read(resBuf, 15_000)
                if (resRead <= 0) {
                    result.error("TIMEOUT", "No final response from device", null)
                    return@Thread
                }
                val res = String(resBuf, 0, resRead, Charsets.US_ASCII)
                Log.d(TAG, "Final response bytes=$resRead hex=${resBuf.take(resRead).joinToString(" ") { "%02X".format(it) }}")
                when {
                    res.contains('K') -> result.success(null)
                    res.contains('E') -> result.error("DEVICE_ERROR", "Device rejected the image", null)
                    else -> result.error("UNKNOWN_RESPONSE", "Unexpected: $res", null)
                }
            } catch (e: Exception) {
                result.error("TRANSFER_ERROR", e.message, null)
            }
        }.start()
    }

    // ── BroadcastReceiver lifecycle ───────────────────────────────────────────

    private fun registerReceiver() {
        if (receiverRegistered) return
        val ctx = appContext ?: return
        val filter = IntentFilter().apply {
            addAction(ACTION_USB_PERMISSION)
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        // RECEIVER_EXPORTED is required on API 33+ for system USB broadcasts.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(usbReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            ctx.registerReceiver(usbReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterReceiver() {
        if (!receiverRegistered) return
        try {
            appContext?.unregisterReceiver(usbReceiver)
        } catch (_: Exception) {}
        receiverRegistered = false
    }

    companion object {
        private const val TAG = "TiggNiziPos"

        // TODO: Confirm the exact magic-frame bytes with the B30 hardware spec.
        // These 4 bytes are sent immediately before the 4-byte JPEG length in
        // the START_RTIMAGE header.
        private val MAGIC_FRAME = byteArrayOf(
            0xA5.toByte(), 0x5A.toByte(), 0xA5.toByte(), 0x5A.toByte()
        )

        // USB bulk read buffers must be at least as large as the endpoint's
        // maxPacketSize (64 bytes for full-speed, 512 for high-speed).
        // 256 bytes is a safe minimum that avoids ArrayIndexOutOfBoundsException
        // when the driver tries to copy a full USB packet into the buffer.
        private const val READ_BUF_SIZE = 256

        private const val CHUNK_SIZE = 4096
    }
}
