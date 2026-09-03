package com.osimono.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.osimono.android.ui.OsimonoApp
import com.osimono.android.ui.theme.OsimonoTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            OsimonoTheme {
                OsimonoApp(container = (application as OsimonoApplication).container)
            }
        }
    }
}
