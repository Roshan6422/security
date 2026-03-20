package com.safeshell.safe_shell_mobile

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.File

object KeystoreHelper {
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val KEY_ALIAS = "SAFE_SHELL_AES_KEY"
    private const val GCM_NONCE_LENGTH = 12 // bytes
    private const val GCM_TAG_LENGTH = 128 // bits

    private fun getOrCreateKey(): SecretKey {
        val ks = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        ks.getKey(KEY_ALIAS, null)?.let { return it as SecretKey }

        val keyGen = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE
        )
        val spec = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .build()
        keyGen.init(spec)
        return keyGen.generateKey()
    }

    fun encrypt(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val secretKey = getOrCreateKey()
        cipher.init(Cipher.ENCRYPT_MODE, secretKey)
        val iv = cipher.iv                 // 12‑byte nonce
        val encrypted = cipher.doFinal(plain)
        // store as:  iv + encrypted
        return iv + encrypted
    }

    fun decrypt(ciphertext: ByteArray): ByteArray {
        if (ciphertext.size < GCM_NONCE_LENGTH) {
            throw IllegalArgumentException("Ciphertext too short")
        }
        val iv = ciphertext.copyOfRange(0, GCM_NONCE_LENGTH)
        val actualCipher = ciphertext.copyOfRange(GCM_NONCE_LENGTH, ciphertext.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val secretKey = getOrCreateKey()
        val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
        cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
        return cipher.doFinal(actualCipher)
    }

    // Security Pass 255: Streaming Encryption for large files
    fun encryptStream(inputPath: String, outputPath: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val secretKey = getOrCreateKey()
        cipher.init(Cipher.ENCRYPT_MODE, secretKey)
        
        FileInputStream(inputPath).use { fis ->
            java.io.FileOutputStream(outputPath).use { fos ->
                fos.write(cipher.iv) // Write IV first
                val buffer = ByteArray(64 * 1024)
                var bytesRead: Int
                while (fis.read(buffer).also { bytesRead = it } != -1) {
                    val output = cipher.update(buffer, 0, bytesRead)
                    if (output != null) fos.write(output)
                }
                val finalOutput = cipher.doFinal()
                if (finalOutput != null) fos.write(finalOutput)
            }
        }
    }

    fun decryptStream(inputPath: String, outputPath: String) {
        FileInputStream(inputPath).use { fis ->
            val iv = ByteArray(GCM_NONCE_LENGTH)
            if (fis.read(iv) != GCM_NONCE_LENGTH) throw Exception("Invalid IV branch")
            
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            val secretKey = getOrCreateKey()
            val spec = GCMParameterSpec(GCM_TAG_LENGTH, iv)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, spec)
            
            java.io.FileOutputStream(outputPath).use { fos ->
                val buffer = ByteArray(64 * 1024)
                var bytesRead: Int
                while (fis.read(buffer).also { bytesRead = it } != -1) {
                    val output = cipher.update(buffer, 0, bytesRead)
                    if (output != null) fos.write(output)
                }
                val finalOutput = cipher.doFinal()
                if (finalOutput != null) fos.write(finalOutput)
            }
        }
    }
}
