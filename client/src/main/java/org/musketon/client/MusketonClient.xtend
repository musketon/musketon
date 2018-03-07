package org.musketon.client

import com.google.protobuf.Message
import java.math.BigInteger
import java.time.Duration
import java.time.Instant
import org.eclipse.xtend.lib.annotations.Accessors
import org.musketon.Musketon
import org.musketon.MusketonDocs
import org.musketon.client.FeatureSpecs.Spec
import org.musketon.client.Messages.Address
import org.musketon.client.Messages.AuditTrail
import org.musketon.client.Messages.Birthdate
import org.musketon.client.Messages.Grant
import org.musketon.client.Messages.Name
import org.musketon.client.NEO.Account.AddressAccount
import org.musketon.client.NEO.Account.PrivateKeyAccount
import org.musketon.client.NEO.Account.PublicKeyAccount
import org.musketon.neo.annotations.OperationDocs

import static extension org.musketon.client.Crypto.*
import static extension org.musketon.client.Util.*
import org.musketon.client.NEO.InvocationArg

class MusketonClient {
	val public NEO neo
	val public PrivateKeyAccount account
	
	val public User user
	val public Consumer consumer
	
	@Accessors(PUBLIC_SETTER)
	int awaitConfirmations = 2
	
	@Accessors(PUBLIC_SETTER)
	boolean debug = false
	
	new(NEO neo, PrivateKeyAccount account) {
		this.neo = neo
		this.account = account
		
		this.user = new User(this)
		this.consumer = new Consumer(this)
	}
	
	static class User {
		val extension MusketonClient context
		
		new(MusketonClient context) {
			this.context = context
		}
		
		def void defineName(Name definition) {
			val spec = FeatureSpecs.name
			defineFeature(definition, spec)
		}
		
		def void defineName((Name.Builder)=>void builder) {
			defineName(Name.newBuilder.with(builder).build)
		}
		
		def void defineBirthdate(Birthdate definition) {
			val spec = FeatureSpecs.birthdate
			defineFeature(definition, spec)
		}
		
		def void defineBirthdate((Birthdate.Builder)=>void builder) {
			defineBirthdate(Birthdate.newBuilder.with(builder).build)
		}
		
		def void defineAddress(Address definition) {
			val spec = FeatureSpecs.address
			defineFeature(definition, spec)
		}
		
		def void defineAddress((Address.Builder)=>void builder) {
			defineAddress(Address.newBuilder.with(builder).build)
		}
				
		def protected <T extends Message> defineFeature(T mainFeature, Spec<T> spec) {
			spec.validate(mainFeature)
			val derivedFeatures = spec.deriveFeatures(mainFeature)
			
			defineSingleFeature(mainFeature, spec.getFeatureId(mainFeature))
			derivedFeatures.forEach [ defineSingleFeature(spec.getFeatureId(it)) ]
		}
		
		def protected defineSingleFeature(Message feature, String featureId) {
			debug ['''Defining feature «featureId»:''']
			debug [ feature.toString.trim ]
			
			val operation = MusketonDocs.User.Feature.Define
			val serializedPayload = feature.toByteArray
			
			debug ['Encrypting payload with private key']
			val encryptedPayload = serializedPayload.encrypt(account.privateKey)
			
			debug ['''Invoking «operation.name» operation''']
			invoke(operation, account.addressBytes, featureId, encryptedPayload)
		}
		
		def <T extends Message> T getFeature(Class<T> featureClass) {
			val featureId = FeatureSpecs.getSpec(featureClass).getFeatureId(featureClass)
			getFeature(featureId) as T
		}
		
		def Message getFeature(String featureId) {
			val featureClass = FeatureSpecs.getSpec(featureId).getFeatureClass(featureId)
			val serialized = getSerializedFeature(featureId)
			if (!serialized.nullOrEmpty)
				FeatureSpecs.parse(serialized, featureClass)
		}
		
		def void deleteFeature(String featureId) {
			val spec = FeatureSpecs.getSpec(featureId)
			
			spec.grantableFeatures.forEach [ deleteSingleFeature ]
		}
		
		def protected deleteSingleFeature(String featureId) {
			debug ['''Deleting feature «featureId»''']
			
			val operation = MusketonDocs.User.Feature.Delete
			
			debug ['''Invoking «operation.name» operation''']
			invoke(operation, account.addressBytes, featureId)
		}
		
		def protected byte[] getSerializedFeature(String featureId) {
			val storageKey = Musketon.Store.StorageKeys.feature(account.addressBytes, featureId)
			val encryptedPayload = neo.getStorage(storageKey)
			if (encryptedPayload.nullOrEmpty) return emptyList
			
			val serialized = encryptedPayload.decrypt(account.privateKey)
			
			serialized
		}
		
		def Grant authorizeIndefinitely(byte[] consumerPubKey, String featureId) {
			authorize(consumerPubKey, featureId, Instant.EPOCH)
		}
		
		def Grant authorizeIndefinitely(PublicKeyAccount consumer, String featureId) {
			authorize(consumer, featureId, Instant.EPOCH)
		}
		
		def Grant authorize(byte[] consumerPubKey, String featureId, Instant expiry) {
			val consumer = neo.getAccountFromPublicKey(consumerPubKey)
			authorize(consumer, featureId, expiry)
		}
		
		def Grant authorize(PublicKeyAccount consumer, String featureId, Instant expiry) {
			debug ['''Authorizing consumer «consumer.address» to access feature «featureId»''']
			
			val operation = MusketonDocs.User.Grant.Authorize
			val license = 'read'
			
			val feature = getSerializedFeature(featureId)
			
			debug ['Encrypting payload with user + consumer keys']
			val encryptedFeature = feature.encrypt(account.privateKey, consumer.publicKey)
			val expiryTimestampSeconds = expiry.epochSecond
			
			debug ['''Invoking «operation.name» operation''']
			invoke(operation, account.addressBytes, consumer.addressBytes, featureId, license, expiryTimestampSeconds, consumer.publicKeyBytes, encryptedFeature)
			
			Grant.newBuilder
				.setConsumer(consumer.address)
				.setExpiry(expiryTimestampSeconds)
				.setLicense(license)
				.build
		}
		
		def void revoke(String consumerAddress, String featureId) {
			val consumer = neo.getAccountFromAddress(consumerAddress)
			revoke(consumer, featureId)
		}
		
		def void revoke(AddressAccount consumer, String featureId) {
			debug ['''Revoking consumer «consumer.address» access to feature «featureId»''']
			val operation = MusketonDocs.User.Grant.Revoke
			
			debug ['''Invoking «operation.name» operation''']
			invoke(operation, account.addressBytes, consumer.addressBytes, featureId)
		}
		
		def Grant getLatestGrant(String consumerAddress, String featureId) {
			val consumer = neo.getAccountFromAddress(consumerAddress)
			getLatestGrant(consumer, featureId)
		}
		
		def Grant getLatestGrant(byte[] consumerPublicKey, String featureId) {
			val consumer = neo.getAccountFromPublicKey(consumerPublicKey)
			getLatestGrant(consumer, featureId)
		}
		
		def Grant getLatestGrant(AddressAccount consumer, String featureId) {
			val storageKey = Musketon.Store.StorageKeys.grant(consumer.addressBytes, account.addressBytes, featureId)
			val storedGrant = neo.getStorage(storageKey)
			if (storedGrant.nullOrEmpty) return null
			
			val components = Musketon.Store.deserialize(storedGrant)
			
			Grant.newBuilder
				.setConsumer(consumer.address)
				.setLicense(components.get(0).toStringUtf8)
				.setIssuedTimestamp(components.get(1).toLong)
				.setExpiry(components.get(2).toLong)
				.build
		}
		
		def String getGrantLicense(String consumerAddress, String featureId) {
			val consumer = neo.getAccountFromAddress(consumerAddress)
			getGrantLicense(consumer, featureId)
		}
		
		def String getGrantLicense(byte[] consumerPublicKey, String featureId) {
			val consumer = neo.getAccountFromPublicKey(consumerPublicKey)
			getGrantLicense(consumer, featureId)
		}
		
		def String getGrantLicense(AddressAccount consumer, String featureId) {
			val grant = getLatestGrant(consumer, featureId)
			if (grant !== null)
				GrantLicense.READ.generateLicense(account.address, featureId, grant)
		}
		
		def AuditTrail getAuditTrail(String consumerAddress, int year) {
			val consumer = neo.getAccountFromAddress(consumerAddress)
			getAuditTrail(consumer, year)
		}
		
		def AuditTrail getAuditTrail(AddressAccount consumer, int year) {
			val storageKey = Musketon.Store.StorageKeys.auditTrail(account.addressBytes, consumer.addressBytes, year.toByteArray)
			val storedAuditTrail = neo.getStorage(storageKey)
			
			val builder = AuditTrail.newBuilder
				.setConsumer(consumer.address)
				.setYear(year)
			
			if (storedAuditTrail.nullOrEmpty) 
				return builder.build
			
			val byte[][][] auditTrailComponents = Musketon.Store.deserialize(storedAuditTrail).map [
				Musketon.Store.deserialize(it)
			]
			
			builder.addAllRecords(auditTrailComponents.map [ recordComponents |
				AuditTrail.Record.newBuilder
					.setTimestamp(recordComponents.get(0).toLong)
					.setFeatureId(recordComponents.get(1).toStringUtf8)
					.setReason(recordComponents.get(2).toStringUtf8)
					.build
			])
			.build
		}
	}
	
	static class Consumer {
		val extension MusketonClient context
		
		new(MusketonClient context) {
			this.context = context
		}
		
		def <T extends Message> T read(byte[] userPublicKey, Class<T> featureClass, String reason) {
			val user = neo.getAccountFromPublicKey(userPublicKey)
			read(user, featureClass, reason)
		}
		
		def <T extends Message> T read(PublicKeyAccount user, Class<T> featureClass, String reason) {
			debug ['''Reading user «user.address» feature of type «featureClass.simpleName»''']
			
			val operation = MusketonDocs.Consumer.Read
			val spec = FeatureSpecs.getSpec(featureClass)
			val featureId = spec.getFeatureId(featureClass)
			val now = Instant.now
			
			debug ['''Invoking «operation.name» operation''']
			invoke(operation, account.addressBytes, user.addressBytes, featureId, reason ?: '')
			
			val storageKey = Musketon.Store.StorageKeys.grant(account.addressBytes, user.addressBytes, featureId)
			val storedGrant = neo.getStorage(storageKey)
			if (storedGrant.nullOrEmpty) return null
			
			val grantComponents = Musketon.Store.deserialize(storedGrant) 
			val expiry = Instant.ofEpochSecond(grantComponents.get(2).toLong)
			if (expiry.epochSecond != Musketon.User.Grant.INDEFINITE_EXPIRY && now > expiry) 
				throw new Exception('Unauthorized, grant has expired')
			
			val storedFeature = grantComponents.get(4)
			
			val decryptedPayload = storedFeature.decrypt(account.privateKey, user.publicKey)
			FeatureSpecs.parse(decryptedPayload, featureClass)
		}
	}
	
	val static CONFIRMATIONS_INTERVAL = Duration.ofSeconds(7)
	val static CONFIRMATIONS_TIMEOUT = Duration.ofSeconds(90)
	
	def protected invoke(OperationDocs operation, Object... args) {
		val txId = neo.invoke(operation.name, args.filterNull.map [ new InvocationArg(neoType, it) ])
		debug ['''Invocation transaction id: «txId»''']
		awaitConfirmation(txId)
		txId
	}
	
	/**
	 * Signature = 0x00,
	 * Boolean = 0x01,
	 * Integer = 0x02,
	 * Hash160 = 0x03,
	 * Hash256 = 0x04,
	 * ByteArray = 0x05,
	 * PublicKey = 0x06,
	 * String = 0x07,
	 * Array = 0x10,
	 * InteropInterface = 0xf0,   
	 * Void = 0xff
	 */
	def getNeoType(Object object) {
		switch object {
			Boolean: '0x01'
			Integer, Long: '0x02'
			BigInteger, byte[]: '0x05'
			String: '0x07'
			Iterable<?>: '0x10'
			Void: '0xff'
			default: throw new UnsupportedOperationException('''No NEO equivalent known of type: «object?.class ?: null»''')
		}
	}
	
	def awaitConfirmation(String txId) {
		var confirmations = 0
		var attempt = 0
		debug ['''Configured to await «awaitConfirmations» confirmation(s)''']
		while(confirmations < awaitConfirmations) {
			val current = confirmations
			debug ['''Awaiting confirmation... («current»/«awaitConfirmations»)''']
			Thread.sleep(CONFIRMATIONS_INTERVAL.toMillis)
			try confirmations = neo.getConfirmations(txId)
			catch(Exception e) {
				if (debug) e.printStackTrace
			}
			
			if (CONFIRMATIONS_INTERVAL.multipliedBy(attempt) > CONFIRMATIONS_TIMEOUT) 
				throw new Exception('''Timeout of «CONFIRMATIONS_TIMEOUT» has been reached, not enough confirmations («current»/«awaitConfirmations»»)''')
			
			attempt++
		}
		debug ['''Transaction confirmed («awaitConfirmations»/«awaitConfirmations»)''']
	}
	
	def debug(=>String log) {
		if (debug) System.out.println(log.apply)
	}
	
	def error(=>String log) {
		System.err.println(log.apply)
	}
}
