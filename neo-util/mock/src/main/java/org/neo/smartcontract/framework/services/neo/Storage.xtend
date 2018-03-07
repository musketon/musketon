package org.neo.smartcontract.framework.services.neo;

import java.math.BigInteger
import java.util.Map

import static extension org.neo.smartcontract.framework.Helper.*
import java.nio.ByteBuffer

class Storage {
	val public static Map<ByteBuffer, byte[]> map = newHashMap
	val static context = new StorageContext
	
	def static StorageContext currentContext() {
		context
	}

	def static byte[] get(StorageContext context, byte[] key) {
		map.get(key.wrap) ?: newByteArrayOfSize(0)
	}

	def static byte[] get(StorageContext context, String key) {
		map.get(key.asByteArray.wrap) ?: newByteArrayOfSize(0)
	}

	def static void put(StorageContext context, byte[] key, byte[] value) {
		map.put(key.wrap, value)
	}
	
	def static void put(StorageContext context, byte[] key, BigInteger value) {
		map.put(key.wrap, value.asByteArray)
	}

	def static void put(StorageContext context, byte[] key, String value) {
		map.put(key.wrap, value.asByteArray)
	}

	def static void put(StorageContext context, String key, byte[] value) {
		map.put(key.asByteArray.wrap, value)
	}
	
	def static void put(StorageContext context, String key, BigInteger value) {
		map.put(key.asByteArray.wrap, value.asByteArray)
	}

	def static void put(StorageContext context, String key, String value) {
		map.put(key.asByteArray.wrap, value.asByteArray)
	}

	def static void delete(StorageContext context, byte[] key) {
		map.remove(key.wrap)
	}

	def static void delete(StorageContext context, String key) {
		map.remove(key.asByteArray.wrap)
	}
	
	def static protected wrap(byte[] bytes) {
		ByteBuffer.wrap(bytes)
	}
}

class StorageContext {

}
