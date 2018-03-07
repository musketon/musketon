package org.musketon.client

import java.time.Year
import org.junit.After
import org.junit.BeforeClass
import org.junit.Test
import org.musketon.client.Messages.Address
import org.musketon.client.Messages.Birthdate
import org.musketon.client.Messages.Birthday
import org.musketon.client.Messages.City
import org.musketon.client.NEO.Account.PrivateKeyAccount

import static org.junit.Assert.*
import static org.musketon.client.MusketonClientTestResources.*

import static extension org.musketon.client.Crypto.*
import static extension org.musketon.client.Util.*

class TestMusketonClient {
	def musketon() { musketonAlice }
	def musketonAlice() { MusketonClientTestResources.musketonAlice }
	def musketonBob() { MusketonClientTestResources.musketonBob }
	
	@BeforeClass
	def static void setup() {
		MusketonClientTestResources.setup
		Util.MOCKED = true
	}
	
	@After
	def void teardown() {
		MusketonClientTestResources.teardown
	}
	
	@Test
	def void testAccount() {
		alice => [
			println(it)
			assertEquals(new PrivateKeyAccount(
				'ALrJ43kdGsRB5KXEpWQkqERo9q3FJ38XUY', 
				'37aeaa78363e3a4b7efd0d644eb01bf75673dd5b'.toByteArrayHex, 
				'04d141a6c375a06e718f65fa97028e44bd17f4150102d9aeb5efd72f030c37bd0a50bfc256f0413ec3afdc851bbda180bd1f1ff5ec9bee8bfbb1c7c190bd2f3d2e'.toByteArrayHex.publicKey,
				'02d141a6c375a06e718f65fa97028e44bd17f4150102d9aeb5efd72f030c37bd0a'.toByteArrayHex,
				'04d141a6c375a06e718f65fa97028e44bd17f4150102d9aeb5efd72f030c37bd0a50bfc256f0413ec3afdc851bbda180bd1f1ff5ec9bee8bfbb1c7c190bd2f3d2e'.toByteArrayHex,
				'cd5fdfd86779c9385e7a63ff97e6420145b1a4d3157dec2a5e6e39a044e8f35a'.toByteArrayHex.privateKey,
				'cd5fdfd86779c9385e7a63ff97e6420145b1a4d3157dec2a5e6e39a044e8f35a'.toByteArrayHex
			), it)
		]
	}
	
	@Test
	def void testCrypto() {
		/** Test encryption with private key as secret */
		val encryped1 = FEATURE_BIRTHDATE.toByteArray.encrypt(alice.privateKey)
		val decrypted1 = Birthdate.parseFrom(encryped1.decrypt(alice.privateKey))
		assertEquals(FEATURE_BIRTHDATE, decrypted1)
		
		/** Test encryption with private-public key / Diffie Hellman secret */
		val encryped2 = FEATURE_BIRTHDATE.toByteArray.encrypt(alice.privateKey, bob.publicKey)
		val decrypted2 = Birthdate.parseFrom(encryped2.decrypt(bob.privateKey, alice.publicKey))
		assertEquals(FEATURE_BIRTHDATE, decrypted2)
	}
	
	@Test
	def void testFeatureCRUD() {
		musketon.user.defineBirthdate(FEATURE_BIRTHDATE)
		
		val getWithFeatureClass = musketon.user.getFeature(Birthdate)
		assertEquals(FEATURE_BIRTHDATE, getWithFeatureClass)
		
		val getWithFeatureId = musketon.user.getFeature(FeatureSpecs.birthdate.group)
		assertEquals(FEATURE_BIRTHDATE, getWithFeatureId)
		
		val getComponent = musketon.user.getFeature(FeatureSpecs.birthdate.birthday)
		assertEquals(FEATURE_BIRTHDAY, getComponent)
		
		musketon.user.deleteFeature(FeatureSpecs.birthdate.group)
		
		val getDeleted = musketon.user.getFeature(Birthdate)
		assertNull(getDeleted)
		
		val getDeletedComponent = musketon.user.getFeature(Birthday)
		assertNull(getDeletedComponent)
	}
	
	@Test
	def void testGrants() {
		val bob = musketonBob.account
		val license = 'read'
		
		musketonAlice.user.defineAddress(FEATURE_ADDRESS)
		
		/** Alice: authorize Bob to read feature birthdate */
		musketonAlice.user.authorize(bob, FeatureSpecs.address.group, EXPIRY)
		
		/** Alice: get freshly authorized grant */
		val grantAddress = musketonAlice.user.getLatestGrant(bob, FeatureSpecs.address.group)
		assertNotNull(grantAddress)
		assertEquals(EXPIRY.epochSecond, grantAddress.expiry)
		assertEquals(bob.getAddress, grantAddress.consumer)
		assertEquals(license, grantAddress.license)
		
		/** Alice: authorize Bob to read feature city */
		musketonAlice.user.authorizeIndefinitely(bob, FeatureSpecs.address.city)
		
		/** Alice: get freshly authorized grant */
		val grantCity = musketonAlice.user.getLatestGrant(bob, FeatureSpecs.address.city)
		assertNotNull(grantAddress)
		assertEquals(0, grantCity.expiry)
		assertEquals(bob.getAddress, grantCity.consumer)
		assertEquals(license, grantCity.license)
		
		/** Alice: revoke Bob's grant */
		musketonAlice.user.revoke(bob, FeatureSpecs.address.group)
		
		/** Alice: get revoked grant */
		val grantRevoked = musketonAlice.user.getLatestGrant(bob, FeatureSpecs.address.group)
		assertNull(grantRevoked)
	}
	
	@Test
	def void testFeatureExchange() {
		val alice = musketonAlice.account
		val bob = musketonBob.account
		
		musketonAlice.user.defineAddress(FEATURE_ADDRESS)
		
		/** Alice: authorize Bob to read feature address and city */
		musketonAlice.user.authorize(bob, FeatureSpecs.address.group, EXPIRY)
		musketonAlice.user.authorizeIndefinitely(bob, FeatureSpecs.address.city)
		
		/** Bob: read out Alice's granted feature */
		val reason1 = 'distribution_center_sorting'
		val grantedFeatureCity = musketonBob.consumer.read(alice, City, reason1)
		assertEquals(FEATURE_CITY, grantedFeatureCity)
		
		/** Alice: request Bob's audit trail */
		val auditTrail1 = musketonAlice.user.getAuditTrail(bob, Year.now.value)
		println(auditTrail1)
		assertNotNull(auditTrail1.recordsList.last)
		assertEquals(FeatureSpecs.address.city, auditTrail1.recordsList.last.featureId)
		assertEquals(reason1, auditTrail1.recordsList.last.reason)
		
		/** Bob: read out Alice's granted feature again */
		val reason2 = 'delivery_scheduling'
		val grantedFeatureAddress = musketonBob.consumer.read(alice, Address, reason2)
		assertEquals(FEATURE_ADDRESS, grantedFeatureAddress)
		
		/** Alice: request Bob's audit trail again */
		val auditTrail2 = musketonAlice.user.getAuditTrail(bob, Year.now.value)
		println(auditTrail2)
		assertNotNull(auditTrail2.recordsList.last)
		assertEquals(FeatureSpecs.address.group, auditTrail2.recordsList.last.featureId)
		assertEquals(reason2, auditTrail2.recordsList.last.reason)
		
		/** Alice: revoke Bob's grant */
		musketonAlice.user.revoke(bob, FeatureSpecs.address.group)
		
		/** Bob: read out Alice's revoked grant */
		val grantedFeatureRevoked = musketonBob.consumer.read(alice, Address, reason1)
		assertNull(grantedFeatureRevoked)
	}
}
