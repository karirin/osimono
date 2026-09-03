package com.osimono.android

import android.app.Application
import com.osimono.android.data.AppContainer

class OsimonoApplication : Application() {
    val container: AppContainer by lazy {
        AppContainer(this)
    }
}
