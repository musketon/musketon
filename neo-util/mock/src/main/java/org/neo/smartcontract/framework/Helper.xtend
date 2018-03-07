package org.neo.smartcontract.framework

import com.google.common.base.Charsets
import java.math.BigInteger

class Helper {
	val static charset = Charsets.UTF_8
	 
	def static BigInteger asBigInteger(byte[] source) {
		new BigInteger(source)
	}
	
	def static byte[] asByteArray(BigInteger source) {
		source.toByteArray
	}
	
	def static byte[] asByteArray(String source) {
		source.getBytes(charset)
	}
	
	def static String asString(byte[] source) {
		new String(source, charset)
	}
	
	def static byte[] concat(byte[] first, byte[] second) {
		first + second
	}
	
	def static byte[] range(byte[] source, int index, int count) {
		source.drop(index).take(count)
	}
	
	def static byte[] take(byte[] source, int count) {
		IterableExtensions.take(source, count)
	}
}
