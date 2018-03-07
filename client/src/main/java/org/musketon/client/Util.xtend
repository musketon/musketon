package org.musketon.client

import com.google.common.base.Charsets
import java.math.BigInteger
import java.nio.file.Paths
import javax.xml.bind.DatatypeConverter

class Util {
	def static byte[] toByteArrayUtf8(String string) {
		string.getBytes(Charsets.UTF_8)
	}
	
	def static String toStringUtf8(byte[] bytes) {
		new String(bytes, Charsets.UTF_8)
	}
	
	def static byte[] toByteArrayHex(String string) {
		DatatypeConverter.parseHexBinary(string)
	}
	
	def static String toStringHex(byte[] bytes) {
		DatatypeConverter.printHexBinary(bytes)
	}
	
	def static long toLong(byte[] bytes) {
		if (bytes.empty) return 0
		new BigInteger(if (MOCKED) bytes else bytes.reverseView).longValue
	}
	
	def static byte[] toByteArray(long n) {
		val bytes = BigInteger.valueOf(n).toByteArray
		if (MOCKED) bytes
		else bytes.reverseView
	}
	
	def static <T> with(T object, (T)=>void procedure) {
		procedure.apply(object)
		object
	}
	
	def static stringBuilder((StringBuilder)=>void builder) {
		new StringBuilder().with(builder).toString
	}
	
	def static path(String root, String... path) {
		Paths.get(root, path).toString
	}
	
	var public static MOCKED = false
}
