package cn.wuewa.dicomflow_app

import net.sf.sevenzipjbinding.ExtractAskMode
import net.sf.sevenzipjbinding.ExtractOperationResult
import net.sf.sevenzipjbinding.IArchiveExtractCallback
import net.sf.sevenzipjbinding.IInArchive
import net.sf.sevenzipjbinding.ISequentialOutStream
import net.sf.sevenzipjbinding.PropID
import net.sf.sevenzipjbinding.SevenZip
import net.sf.sevenzipjbinding.SevenZipException
import net.sf.sevenzipjbinding.impl.RandomAccessFileInStream
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile

object SevenZipExtract {
    private val lock = Any()
    @Volatile private var inited = false

    fun extract(archivePath: String, destPath: String) {
        ensureInit()
        val dest = File(destPath)
        dest.mkdirs()
        RandomAccessFile(archivePath, "r").use { raf ->
            SevenZip.openInArchive(null, RandomAccessFileInStream(raf)).use { archive ->
                val n = archive.numberOfItems
                val indices = IntArray(n) { it }
                archive.extract(indices, false, Callback(archive, dest))
            }
        }
    }

    private fun ensureInit() {
        if (inited) return
        synchronized(lock) {
            if (inited) return
            try {
                SevenZip.initSevenZipFromPlatformJAR()
            } catch (_: Exception) {
                // AAR already ships jniLibs; first API call loads them.
            }
            inited = true
        }
    }
}

private class Callback(
    private val inArchive: IInArchive,
    private val destDir: File,
) : IArchiveExtractCallback {
    private var output: FileOutputStream? = null

    override fun setTotal(total: Long) {}

    override fun setCompleted(complete: Long) {}

    override fun prepareOperation(extractAskMode: ExtractAskMode?) {}

    override fun setOperationResult(extractOperationResult: ExtractOperationResult?) {
        try {
            output?.close()
        } finally {
            output = null
        }
        if (extractOperationResult != null && extractOperationResult != ExtractOperationResult.OK) {
            throw SevenZipException("extract failed: $extractOperationResult")
        }
    }

    override fun getStream(index: Int, extractAskMode: ExtractAskMode?): ISequentialOutStream? {
        if (extractAskMode != ExtractAskMode.EXTRACT) return null
        val isFolder = inArchive.getProperty(index, PropID.IS_FOLDER) as Boolean? ?: false
        if (isFolder) return null
        val raw = inArchive.getProperty(index, PropID.PATH) as String? ?: return null
        val rel = raw.replace('\\', '/').trim('/')
        if (rel.isEmpty() || rel.contains("..")) {
            throw SevenZipException("illegal archive path: $raw")
        }
        val outFile = File(destDir, rel)
        val base = destDir.canonicalFile
        val target = outFile.canonicalFile
        if (target != base && !target.path.startsWith(base.path + File.separator)) {
            throw SevenZipException("illegal archive path: $raw")
        }
        outFile.parentFile?.mkdirs()
        output = FileOutputStream(outFile)
        return ISequentialOutStream { data ->
            output!!.write(data)
            data.size
        }
    }
}
