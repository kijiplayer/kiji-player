allprojects {
    repositories {
        google()
        mavenCentral()
        // Solo InnerTubeX sale de JitPack; nada más se baja de ahí.
        maven("https://jitpack.io") {
            content { includeGroup("com.github.MetrolistGroup.innertubex") }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
