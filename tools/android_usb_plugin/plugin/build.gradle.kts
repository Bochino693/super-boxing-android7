import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// O AUSBC 3.2.7 ainda publica duas dependencias opcionais no antigo JCenter.
// A ponte do Punch Challenge usa apenas captura UVC/NV21, portanto nenhuma
// delas e necessaria. Excluir globalmente evita falha de resolucao no Gradle.
configurations.configureEach {
    exclude(group = "com.gyf.immersionbar", module = "immersionbar")
    exclude(group = "com.zlc.glide", module = "webpdecoder")
}

// TODO: Update value to your plugin's name.
val pluginName = "PunchUsbSerial"

// TODO: Update value to match your plugin's package name.
val pluginPackageName = "com.lazersport.punch.usbserial"

android {
    namespace = pluginPackageName
    compileSdk = 36

    buildFeatures {
        buildConfig = true
    }

    defaultConfig {
        minSdk = 24

        manifestPlaceholders["godotPluginName"] = pluginName
        manifestPlaceholders["godotPluginPackageName"] = pluginPackageName
        buildConfigField("String", "GODOT_PLUGIN_NAME", "\"${pluginName}\"")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}

dependencies {
    // GODOT 3.6: a biblioteca do motor não está no Maven. Ela vem do modelo
    // Android do próprio projeto (android/build/libs), que o GERAR_APK extrai
    // antes de compilar este plugin. Só para compilar: o APK já a tem.
    compileOnly(fileTree(mapOf("dir" to "../../../android/build/libs/release", "include" to listOf("godot-lib*.aar"))))
    implementation("com.github.mik3y:usb-serial-for-android:3.11.0")
    implementation("com.github.jiangdongguo.AndroidUSBCamera:libausbc:3.2.7")
    implementation("com.github.jiangdongguo.AndroidUSBCamera:libuvc:3.2.7")
}

// Nome do .aar gerado (PunchUsbSerial-release.aar). `archivesBaseName` é
// recurso antigo do Gradle e gerava aviso de "Deprecated Gradle features".
base {
    archivesName.set(pluginName)
}
