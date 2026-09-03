package cn.wuewa.dicomflow_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val extractExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "extract") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val archive = call.argument<String>("archive")
            val dest = call.argument<String>("dest")
            if (archive.isNullOrEmpty() || dest.isNullOrEmpty()) {
                result.error("SEVENZIP", "archive and dest are required", null)
                return@setMethodCallHandler
            }
            extractExecutor.execute {
                try {
                    SevenZipExtract.extract(archive, dest)
                    runOnUiThread { result.success(0) }
                } catch (e: Throwable) {
                    runOnUiThread { result.error("SEVENZIP", e.message ?: e.javaClass.simpleName, null) }
                }
            }
        }
    }

    companion object {
        private const val CHANNEL = "cn.wuewa.dicomflow/sevenzip"
    }
}
