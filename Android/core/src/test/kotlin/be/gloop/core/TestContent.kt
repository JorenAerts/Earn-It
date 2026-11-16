package be.gloop.core

import be.gloop.core.content.ContentSource
import java.io.File

/** The real Shared/Config as a ContentSource. */
val sharedSource = ContentSource { path -> File(SharedConfig.dir, path).takeIf { it.isFile }?.readText() }
