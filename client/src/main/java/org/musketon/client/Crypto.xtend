package org.musketon.client

import de.oehme.xtend.contrib.Cached
import java.math.BigInteger
import java.security.KeyFactory
import java.security.KeyPair
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.PublicKey
import java.security.SecureRandom
import java.security.Security
import java.security.spec.ECPoint
import java.security.spec.ECPublicKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyAgreement
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec
import org.bouncycastle.jce.ECNamedCurveTable
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.jce.spec.ECNamedCurveSpec
import org.bouncycastle.jce.spec.ECPrivateKeySpec

import static extension java.util.Arrays.*

class Crypto {
	@Cached 
	def static boolean load() {
		Security.addProvider(new BouncyCastleProvider)
		true
	}
	
	val static ECDH = 'ECDH'
	val static SHA = 'SHA-1'
	val static EC = 'EC'
	val static AES = 'AES/CBC/PKCS5Padding'
	val static secp256r1 = 'secp256r1'
	
	def static publicKey(byte[] keyBytes) {
		if (keyBytes.length != 65) 
			throw new IllegalArgumentException('Public key bytes must be of size 65')
		
		val spec = ECNamedCurveTable.getParameterSpec(secp256r1)
		val params = new ECNamedCurveSpec(secp256r1, spec.curve, spec.g, spec.n, spec.h, spec.seed)
		val x = new BigInteger(1, keyBytes.copyOfRange(1, 33))
		val y = new BigInteger(1, keyBytes.copyOfRange(33, 65))
		val point = new ECPoint(x, y)
		val ecPublicKeySpec = new ECPublicKeySpec(point, params)
		
		KeyFactory.getInstance(EC).generatePublic(ecPublicKeySpec)
	}
	
	def static privateKey(byte[] key) {
		val spec = ECNamedCurveTable.getParameterSpec(secp256r1)
		val ecPrivateKeySpec = new ECPrivateKeySpec(new BigInteger(1, key), spec)
		
		KeyFactory.getInstance(EC).generatePrivate(ecPrivateKeySpec)
	}
	
	def static keyPair(byte[] publicKey, byte[] privateKey) {
		new KeyPair(publicKey(publicKey), privateKey(privateKey))
	}
	
	def static generateSecret(PrivateKey privateKey, PublicKey publicKey) {
		val agreement = KeyAgreement.getInstance(ECDH)
		agreement.init(privateKey)
		agreement.doPhase(publicKey, true)		
		agreement.generateSecret
	}
	
	def static encrypt(byte[] payload, PrivateKey sender, PublicKey receiver) {
		val secret = generateSecret(sender, receiver)
		payload.encrypt(secret)
	}
	
	def static decrypt(byte[] payload, PrivateKey receiver, PublicKey sender) {
		val secret = generateSecret(receiver, sender)
		payload.decrypt(secret)
	}
	
	def static encrypt(byte[] payload, PrivateKey owner) {
		val secret = owner.encoded
		payload.encrypt(secret)
	}
	
	def static decrypt(byte[] payload, PrivateKey owner) {
		val secret = owner.encoded
		payload.decrypt(secret)
	}
	
	def static byte[] encrypt(byte[] payload, byte[] secret) {
		val byte[] vector = generateInitializationVector
		val vectorSpec = new IvParameterSpec(vector)
		
		val byte[] secretHash = secret.hash128
		val secretSpec = new SecretKeySpec(secretHash, AES)
		
		val cipher = Cipher.getInstance(AES)
		cipher.init(Cipher.ENCRYPT_MODE, secretSpec, vectorSpec)
		vector + cipher.doFinal(payload)
	}
	
	def static byte[] decrypt(byte[] payload, byte[] secret) {
		val byte[] payloadWithoutVector = payload.drop(VECTOR_SIZE)
		val byte[] vector = payload.take(VECTOR_SIZE)
		val vectorSpec = new IvParameterSpec(vector)
		
		val byte[] secretHash = secret.hash128
		val secretSpec = new SecretKeySpec(secretHash, AES)
		
		val cipher = Cipher.getInstance(AES)
		cipher.init(Cipher.DECRYPT_MODE, secretSpec, vectorSpec)
		cipher.doFinal(payloadWithoutVector)
	}
	
	val static random = SecureRandom.getInstance('SHA1PRNG')
	
	val static VECTOR_SIZE = 128 / Byte.SIZE
	
	/** Generates a random 128-bit initialization vector to be used in ciphering */
	def static generateInitializationVector() {
		val iv = newByteArrayOfSize(VECTOR_SIZE)
		random.nextBytes(iv)
		iv
	}
	
	def static byte[] hash128(byte[] message) {
		MessageDigest.getInstance(SHA).digest(message).take(16)
	}
}
