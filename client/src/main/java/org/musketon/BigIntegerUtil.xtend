package org.musketon

import java.math.BigInteger

class BigIntegerUtil {
	/**
	 * Method in shadowed class to restore the {@code unsupported instruction __i2l} workaround used in the smart contract with the real code
	 */
	def static intToBigInteger(int n) {
		BigInteger.valueOf(n)
	}
}
