allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    layout.projectDirectory
        .dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
    // Force apply org.jetbrains.kotlin.android at configuration phase for file_picker under AGP 9
    if (project.name.contains("file_picker") || project.name.contains("filepicker")) {
        project.plugins.apply("org.jetbrains.kotlin.android")
    }
}

fun configureNamespace(proj: Project) {
    val android = proj.extensions.findByName("android")
    if (android != null) {
        try {
            val getNamespace = android.javaClass.methods.firstOrNull { it.name == "getNamespace" }
            val currentNamespace = getNamespace?.invoke(android) as? String
            if (currentNamespace == null) {
                val setNamespace = android.javaClass.methods.firstOrNull { 
                    it.name == "setNamespace" && it.parameterTypes.size == 1 && it.parameterTypes[0] == String::class.java 
                }
                setNamespace?.invoke(android, "de.yurtemre.sonora.fallback." + proj.name.replace("-", "_"))
            }
        } catch (e: Exception) {
            // Ignore
        }
    }
}

subprojects {
    if (project.state.executed) {
        configureNamespace(project)
    } else {
        project.afterEvaluate {
            configureNamespace(this)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
