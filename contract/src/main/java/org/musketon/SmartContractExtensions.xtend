package org.musketon

import static extension org.musketon.BigIntegerUtil.*
import static extension org.neo.smartcontract.framework.Helper.*

class SmartContractExtensions extends JavaArrayUtil {
	def static isNullOrEmptyByteArray(byte[] value) {
		value === null || value.length == 0
	}
	
	def static isNullOrEmpty(byte[][] value) {
		value === null || value.length == 0
	}
	
	def static <T> T[] newArray(T... objects) {
		objects
	}
	
	def static byte[] newByteArray(byte... objects) {
		objects
	}
	
	def static int[] newIntArray(int... objects) {
		objects
	}
	
	def static byte[][] slice(byte[] bytes, int size, byte[][] container) {
		sliceRecursive(bytes, size, 0, container)
	}
	
	def static protected byte[][] sliceRecursive(byte[] bytes, int size, int cursor, byte[][] slices) {
		if (bytes.length == 0) return slices
		val currentSlice = bytes.take(size)
		
		slices.set(cursor, currentSlice)
		
		if (bytes.length <= size) return slices
		else {
			val remainder = bytes.range(size, bytes.length - size)
			sliceRecursive(remainder, size, cursor + 1, slices)
		}
	}
	
	def static byte[][] sliceWeighted(byte[] bytes, int... sizes) {
		val slices = newTwoDimByteArray(sizes.length)
		var cursor = 0
		for (var i = 0; i < sizes.length; i++) {
			val currentSliceSize = sizes.get(i)
			val currentSlice = bytes.range(cursor, currentSliceSize)
			slices.set(i, currentSlice)
			cursor += currentSliceSize
		}
		slices
	}
	
	/**
	 * Serializes payload as the payload's value count + each value's size + each value.
	 * Example: when payload is ['john', 'doe'], how this will be concatenated is: 
	 * {@code 2} (value count) + {@code 4} ('john' length) + {@code 3} ('doe' length) + {@code john} (value 1) + {@code doe} (value 2)
	 */
	def static serialize(byte[]... payload) {
		var byte[] serialized = null
		
		val payloadValuesCount = payload.length.intToBigInteger.asByteArray
		serialized = payloadValuesCount
		
		for (value : payload) {
			val valueSize = value.length.intToBigInteger.asByteArray
			serialized = serialized.concat(valueSize)
		}
		for (value : payload) {
			serialized = serialized.concat(value)
		}
		
		serialized
	}
	
	def static deserialize(byte[] serialized) {
		val countsSize = 1
		val valuesCountSize = 1 * countsSize
		val valuesCount = serialized.range(0, valuesCountSize).asBigInteger.intValue
		
		val valueSizesBytes = serialized.range(valuesCountSize, valuesCount * countsSize).slice(countsSize, newTwoDimByteArray(valuesCount))
		val valueSizes = newIntArrayOfSize(valuesCount)
		for (var i = 0; i < valueSizesBytes.length; i++) {
			valueSizes.set(i, valueSizesBytes.get(i).asBigInteger.intValue)
		}
		
		val metadataSize = valuesCountSize + valuesCount * countsSize
		val fullPayload = serialized.range(metadataSize, serialized.length - metadataSize)
		fullPayload.sliceWeighted(valueSizes)
	}
}
