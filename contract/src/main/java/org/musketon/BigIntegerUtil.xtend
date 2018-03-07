package org.musketon

import java.math.BigInteger

import static extension org.neo.smartcontract.framework.Helper.*

class BigIntegerUtil {
	/** 
	 * Method into separate util class, to be able to shadow it for usage outside of smart contracts,
	 * as this implementation is a workaround for the neoj int-to-long conversion {@code unsupported instruction __i2l} 
	 * limitation/bug. In a normal JVM, non NeoVM environment, this should just be: {@code BigInteger.valueOf(n)}
	 */
	def static intToBigInteger(int n) {
		new BigInteger(String.valueOf(n).asByteArray)
	}
}
