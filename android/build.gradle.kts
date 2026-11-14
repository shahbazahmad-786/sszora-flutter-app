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
subprojects {
    project.evaluationDependsOn(":app")
}

// Windows locks AGP's CMake timing log, so the jni plugin's native build is
// replaced by the prebuilt libdartjni.so in app/src/main/jniLibs.
subprojects {
    if (name != "jni") return@subprojects
    afterEvaluate {
        tasks.matching {
            it.name.contains("CMake") || it.name.contains("externalNativeBuild")
        }.configureEach {
            onlyIf { false }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
