package com.example.incoin

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.incoin/python_bot"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Ensure Chaquopy is initialized
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start_order_grab" -> {
                    val username = call.argument<String>("username")
                    val password = call.argument<String>("password")
                    
                    if (username == null || password == null) {
                        result.error("INVALID_ARGS", "Username and password cannot be null", null)
                        return@setMethodCallHandler
                    }

                    // Run the python script in a background coroutine to avoid blocking the main UI thread
                    CoroutineScope(Dispatchers.IO).launch {
                        try {
                            val py = Python.getInstance()
                            // The python file must be named incoin_bot.py inside src/main/python
                            val module = py.getModule("incoin_bot")
                            
                            // Call the function explicitly mapping to the python logic
                            val pyResult = module.callAttr("start_order_grab", username, password)
                            
                            withContext(Dispatchers.Main) {
                                result.success(pyResult.toString())
                            }
                        } catch (e: Exception) {
                            withContext(Dispatchers.Main) {
                                result.error("PYTHON_ERROR", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
