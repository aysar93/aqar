package com.andalus.aqar

import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        logNavigationBar("onCreate/afterSuper")
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        window.decorView.post { logNavigationBar("firstFlutterFrame/posted") }
    }

    override fun onResume() {
        super.onResume()
        window.decorView.post { logNavigationBar("onResume/posted") }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            window.decorView.post { logNavigationBar("windowVisible/posted") }
        }
    }

    // Temporary read-only diagnostics: do not change any window settings.
    @Suppress("DEPRECATION")
    private fun logNavigationBar(stage: String) {
        val color = window.navigationBarColor
        val contrast = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced.toString()
        } else {
            "unsupported"
        }
        val controller = WindowCompat.getInsetsController(window, window.decorView)
        Log.i(
            "AqarNavProbe",
            "stage=$stage sdk=${Build.VERSION.SDK_INT} " +
                "color=0x${Integer.toHexString(color).padStart(8, '0')} " +
                "contrastEnforced=$contrast " +
                "lightNavigationBars=${controller.isAppearanceLightNavigationBars} " +
                "hasWindowFocus=${window.decorView.hasWindowFocus()}"
        )
    }
}
