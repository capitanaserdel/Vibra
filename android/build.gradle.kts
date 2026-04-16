import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build directory
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// 🔥 FIX JVM mismatch safely (NO android{} touching)
subprojects {

    // ✅ Force Java & Kotlin to 11 (Aggressive override for all plugins)
    fun alignTargets(p: Project) {
        // 1. Force the Android Extension (if it exists)
        if (p.hasProperty("android")) {
            try {
                val android = p.extensions.getByName("android")
                val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
                val javaVersionClass = Class.forName("org.gradle.api.JavaVersion")
                val v11 = javaVersionClass.getField("VERSION_11").get(null)
                compileOptions.javaClass.getMethod("setSourceCompatibility", v11.javaClass).invoke(compileOptions, v11)
                compileOptions.javaClass.getMethod("setTargetCompatibility", v11.javaClass).invoke(compileOptions, v11)
            } catch (e: Exception) {
                // Ignore if not a standard Android project structure
            }
        }

        // 2. Force Java tasks
        p.tasks.withType(JavaCompile::class.java).configureEach {
            sourceCompatibility = "11"
            targetCompatibility = "11"
        }

        // 3. Force Kotlin tasks
        p.tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java).configureEach {
            try {
                // Modern Kotlin 2.0+ DSL
                val compilerOptions = this.javaClass.getMethod("getCompilerOptions").invoke(this)
                val jvmTargetProperty = compilerOptions.javaClass.getMethod("getJvmTarget").invoke(compilerOptions)
                val jvmTargetClass = Class.forName("org.jetbrains.kotlin.gradle.dsl.JvmTarget")
                val targetValue = jvmTargetClass.getField("JVM_11").get(null)
                jvmTargetProperty.javaClass.getMethod("set", targetValue.javaClass).invoke(jvmTargetProperty, targetValue)
            } catch (e: Exception) {
                try {
                    // Older Kotlin DSL
                    @Suppress("DEPRECATION")
                    this.javaClass.getMethod("getKotlinOptions").invoke(this).let { kOptions ->
                        kOptions.javaClass.getMethod("setJvmTarget", String::class.java).invoke(kOptions, "11")
                    }
                } catch (e2: Exception) {}
            }
        }
    }

    // Namespace fix (Project-state safe)
    fun injectNamespace(p: Project) {
        if (p.name == "on_audio_query_android") {
            try {
                val android = p.extensions.getByName("android")
                val method = android.javaClass.getMethod("setNamespace", String::class.java)
                method.invoke(android, "com.lucasjosino.on_audio_query")
            } catch (_: Exception) {}
        }
    }

    if (project.state.executed) {
        alignTargets(project)
        injectNamespace(project)
    } else {
        afterEvaluate { 
            alignTargets(this)
            injectNamespace(this) 
        }
    }
}

// Clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}