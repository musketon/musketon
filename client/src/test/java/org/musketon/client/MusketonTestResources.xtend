package org.musketon.client

import de.oehme.xtend.contrib.Cached
import java.time.Duration
import org.musketon.Musketon
import org.musketon.client.Messages.Address
import org.musketon.client.Messages.Birthdate
import org.musketon.client.Messages.Birthday
import org.musketon.client.Messages.City
import org.musketon.client.NEO.Account.PrivateKeyAccount
import org.neo.smartcontract.framework.services.neo.Storage

import static extension org.musketon.client.Util.*
import java.time.Instant
import java.math.BigInteger

class MusketonClientTestResources {
	val public static FEATURE_BIRTHDATE = Birthdate.newBuilder.setYear(2008).setMonth(10).setDay(31).build
	val public static FEATURE_BIRTHDAY = Birthday.newBuilder.setMonth(10).setDay(31).build
	
	val public static FEATURE_ADDRESS = Address.newBuilder
		.setAddressLine1('1600 Pennsylvania Ave')
		.setCity('Washington, D.C.')
		.setPostalCode('20500')
		.setCountry('US')
		.build
	
	val public static FEATURE_CITY = City.newBuilder
		.setCity('Washington, D.C.')
		.setCountry('US')
		.build
	
	val public static NOW = Instant.now
	val public static EXPIRY = NOW.plus(Duration.ofDays(3))
	
	val public static ALICE_WIF = 'L46w1ofB2576PLuj3bRvdhEtf6ZZdcYLkPwguUdNe4dkj41U8DhM'
	val public static BOB_WIF = 'KwUaQ7giAXmiB5AMJAL6yKdTiefN9WfRVH39xANndrpR8BRT9bFi'
	
	@Cached
	def static PrivateKeyAccount alice() {
		neo.getAccountFromWif(ALICE_WIF)
	}
	
	@Cached
	def static PrivateKeyAccount bob() {
		neo.getAccountFromWif(BOB_WIF)
	}
	
	@Cached
	def static MusketonClient musketonAlice() {
		new MusketonClient(neo, alice) => [
			awaitConfirmations = 0
		]
	}
	
	@Cached
	def static MusketonClient musketonBob() {
		new MusketonClient(neo, bob) => [
			awaitConfirmations = 0
		]
	}
	
	@Cached
	def static NEO neo() {
		new MusketonClientTestResources.MockNeon
	}
	
	def static void setup() {
		Crypto.load
	}
	
	def static void teardown() {
		Storage.map.clear
	}
	
	static class MockNeon extends Neon {
		new() {
			/** Skip the net and the contract script hash */
			super(null, null, null, '/usr/local/bin/node', 'src/main/neon')
		}
		
		/** For unit tests, send it to the local/mocked contract's Main directly */
		override invoke(String operation, InvocationArg... args) {
			if (operation === null || args.contains(null)) throw new IllegalArgumentException('Invocation args cannot contain null')
			val invocation = Musketon.Main(operation, args.map [ value ].map [ 
				switch it {
					byte[]: it
					String: toByteArrayUtf8
					BigInteger: toByteArray
					Long: toByteArray
					default: throw new IllegalArgumentException('Unknwon type ' + class)
				}
			])
			if (invocation.head.toStringUtf8 == 'error') println(invocation.last.toStringUtf8)
		}
		
		override getStorage(byte[] key) {
			/** Get the data out of the map-backed, local/mock Storage */
			Storage.get(Storage.currentContext, key)
		}
	}
}
