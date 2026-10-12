allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Jitsi y sus dependencias androidx exigen compileSdk >= 35, pero el plugin
// trae 34. Forzamos 36 en los módulos de plugins (no en :app).
subprojects {
    val sub = this
    if (sub.name != "app") {
        val forceCompileSdk = {
            sub.extensions
                .findByType(com.android.build.gradle.BaseExtension::class.java)
                ?.compileSdkVersion(36)
            Unit
        }
        if (sub.state.executed) forceCompileSdk() else sub.afterEvaluate { forceCompileSdk() }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}