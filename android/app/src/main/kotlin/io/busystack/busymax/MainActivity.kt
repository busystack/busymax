package io.busystack.busymax

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Isolated native acceptance must keep rendering during long fixture
        // operations. This window flag changes no device setting or lock policy.
        if (packageName == "io.busystack.busymax.caldavqa") {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }
}
