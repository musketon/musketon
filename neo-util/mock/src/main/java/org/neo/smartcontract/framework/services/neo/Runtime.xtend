package org.neo.smartcontract.framework.services.neo;

class Runtime {
	var public static byte[] mockWitness
	
	//def native static TriggerType trigger()

	def static boolean checkWitness(byte[] hashOrPubkey) {
		mockWitness === null || hashOrPubkey == mockWitness
	}

	def static void notify(Object... state) {
		
	}

	def static void log(String message) {
		println(message)
	}
}
