package cn.wuewa.dicomflow_app

import net.sf.sevenzipjbinding.ExtractAskMode
import net.sf.sevenzipjbinding.ExtractOperationResult
import net.sf.sevenzipjbinding.IArchiveExtractCallback
import net.sf.sevenzipjbinding.ICryptoGetTextPassword
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
            // Android AAR ships lib/ABI/lib7-Zip-JBinding.so. Do not call
            // initSevenZipFromPlatformJAR(): that extracts a Linux-arm artifact
            // from the JAR and leaves JNI unloaded, which SIGSEGVs on rar.
            System.loadLibrary("7-Zip-JBinding")
            SevenZip.initLoadedLibraries()
            inited = true
        }
    }
}

private class Callback(
    private val inArchive: IInArchive,
    private val destDir: File,
) : IArchiveExtractCallback, ICryptoGetTextPassword {
    private var output: FileOutputStream? = null
    private val destCanon = destDir.canonicalFile

    override fun setTotal(total: Long) {}

    override fun setCompleted(complete: Long) {}

    override fun prepareOperation(extractAskMode: ExtractAskMode?) {}

    override fun cryptoGetTextPassword(): String = ""

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

    override fun getStream(index: Int, extractAskMode: ExtractAskMode?): ISequentialOutStream {
        if (extractAskMode != ExtractAskMode.EXTRACT) {
            return ISequentialOutStream { data -> data.size }
        }
        val isFolder = inArchive.getProperty(index, PropID.IS_FOLDER) as? Boolean ?: false
        val raw = (inArchive.getProperty(index, PropID.PATH) as? String).orEmpty()
        val rel = raw.replace('\\', '/').trim('/')
        if (rel.isEmpty()) {
            return ISequentialOutStream { data -> data.size }
        }
        if (rel.contains("..")) {
            throw SevenZipException("illegal archive path: $raw")
        }
        val outFile = File(destDir, rel)
        val target = outFile.canonicalFile
        if (target != destCanon && !target.path.startsWith(destCanon.path + File.separator)) {
            throw SevenZipException("illegal archive path: $raw")
        }
        if (isFolder) {
            outFile.mkdirs()
            return ISequentialOutStream { data -> data.size }
        }
        outFile.parentFile?.mkdirs()
        output = FileOutputStream(outFile)
        return ISequentialOutStream { data ->
            output!!.write(data)
            data.size
        }
    }
}
