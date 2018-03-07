package org.musketon

import java.math.BigInteger
import org.musketon.Musketon.User.Grant
import org.musketon.Musketon.User.Grant.AuditTrail
import org.musketon.Musketon.Util.NEO
import org.musketon.neo.annotations.NEOSmartContract
import org.musketon.neo.annotations.NEOSmartContract.Operation
import org.neo.smartcontract.framework.SmartContract
import org.neo.smartcontract.framework.services.neo.Blockchain
import org.neo.smartcontract.framework.services.neo.Runtime
import org.neo.smartcontract.framework.services.neo.Storage

import static org.musketon.JavaArrayUtil.*
import static org.musketon.Musketon.Util.Messaging.*

import static extension org.musketon.BigIntegerUtil.*
import static extension org.musketon.SmartContractExtensions.*
import static extension org.neo.smartcontract.framework.Helper.*

@NEOSmartContract
class Musketon extends SmartContract {
	/** 
	 * @return an array or byte arrays, with the head always being the invocation status
	 */
	def static byte[][] Main(String operation, byte[]... args) {
		/** 
		 * Auto-generated invocation arg parsing by Xtend active annotation @org.musketon.neo.annotations.NEOSmartContract.
		 * The generated Java code is located in the {@code build/xtend} folder. 
		 */
		execute(operation, args)
	}
	
	/**
	 * Ping
	 * @return Boolean status, String pong
	 */
	@Operation
	def static byte[][] ping() {
		ok('pong'.asByteArray)
	}
	
	/** 
	 * Echos the input
	 * @return Boolean status, String input
	 */
	@Operation
	def static byte[][] echo(byte[] input) {
		ok(input)
	}
	
	
	// USER API /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	static class User {
		def static validateCurrent(byte[] userAddress) {
			NEO.Address.validateCurrent(userAddress)
		}
		
		def static validate(byte[] userAddress) {
			NEO.Address.validate(userAddress)
		}
		
		static class Feature {
			/** 
			 * Define feature of specified featureId
			 * @return Boolean status
			 */
			@Operation
			def static byte[][] define(byte[] userAddress, String featureId, byte[] payload) {
				val error = User.validateCurrent(userAddress) ?: Feature.validatePayload(payload)
				if (error !== null) 
					return error(error)
				
				Store.putFeature(userAddress, featureId, payload)
				
				ok
			}
			
			/** 
			 * Delete feature of specified featureId
			 * @return Boolean status
			 */
			@Operation
			def static byte[][] delete(byte[] userAddress, String featureId) {
				val error = User.validateCurrent(userAddress)
				if (error !== null) 
					return error(error)
				
				Store.deleteFeature(userAddress, featureId)
				
				ok
			}
			
			/** 
			 * Get feature of specified featureId
			 * @return Boolean status, ByteArray payload
			 */
			def static byte[][] get(byte[] userAddress, String featureId) {
				val error = User.validateCurrent(userAddress)
				if (error !== null) 
					return error(error)
				
				val payload = Store.getFeature(userAddress, featureId)
				
				ok(payload)
			}
			
			def static validatePayload(byte[] payload) {
				if (payload.isNullOrEmptyByteArray) {
					'Payload cannot be empty'
				}
			}
		}
		
		static class Grant {
			/** 
			 * Grant a consumer access to a feature until the expiry timestamp
			 * @return String status
			 */
			@Operation
			def static byte[][] authorize(byte[] userAddress, byte[] consumerAddress, String featureId, String license, BigInteger expiry, byte[] consumerPubKey, byte[] payload) {
				val error = User.validateCurrent(userAddress)
				if (error !== null) 
					return error(error)
				
				val issued = NEO.timestamp
				Store.putGrant(consumerAddress, userAddress, featureId, license, issued, expiry, consumerPubKey, payload)
				
				ok
			}
			
			/** 
			 * See the latest issued grant for a specific consumer and feature.
			 * @return String status, String license, BigInteger issuedTimestamp, BigInteger expiryTimestamp, ByteArray consumerPubKey, ByteArray payload
			 */
			@Operation
			def static byte[][] getLatest(byte[] userAddress, byte[] consumerAddress, String featureId) {
				val error = User.validateCurrent(userAddress)
				if (error !== null) 
					return error(error)
				
				val grant = Store.getGrant(consumerAddress, userAddress, featureId)
				if (grant.length == 0) 
					return error('There is no grant for requested feature to consumer')
				
				ok(grant)
			}
			
			/** 
			 * Revoke a grant for consumer and feature.
			 * @return String status
			 */
			@Operation
			def static byte[][] revoke(byte[] userAddress, byte[] consumerAddress, String featureId) {
				val error = User.validateCurrent(userAddress)
				if (error !== null) 
					return error(error)
				
				Store.deleteGrant(consumerAddress, userAddress, featureId)
				
				ok
			}
			
			val public static INDEFINITE_EXPIRY = 0L
			
			def static isExpired(BigInteger expiry, BigInteger currentTimestamp) {
				expiry.longValue !== INDEFINITE_EXPIRY && currentTimestamp > expiry
			}
			
			static class AuditTrail {
				def static getShard(BigInteger timestamp) {
					timestamp.year
				}
				
				val public static YEAR_SECONDS = 31557600L
				val public static EPOCH_YEAR = 1970L
				
				def static getYear(BigInteger now) {
					now / BigInteger.valueOf(YEAR_SECONDS) + BigInteger.valueOf(EPOCH_YEAR)
				}
			}
		}
	}
	
	
	// CONSUMER API /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	static class Consumer {
		/** 
		 * Read the specified feature. Will only succeed if the user granted the consumer access and if grant has not yet expired. 
		 * Every read will be logged and visible to the user.
		 * @return String status, ByteArray featurePayload
		 */	
		@Operation
		def static byte[][] read(byte[] consumerAddress, byte[] userAddress, String featureId, String reason) {
			val error = Consumer.validateCurrent(consumerAddress) ?: User.validate(userAddress)
			if (error !== null) return error(error)
			
			val grant = Store.getGrant(consumerAddress, userAddress, featureId)
			if (grant.length == 0) 
				return error('Unauthorized, requested feature is not granted to consumer')
			
			val now = NEO.timestamp
			val expiry = grant.get(2).asBigInteger
			if (Grant.isExpired(expiry, now))
				return error('Unauthorized, grant has expired')
			
			val payload = grant.get(4) ?: newByteArrayOfSize(0)
			if (payload.length == 0)
				return error('Requested feature is not defined or has been deleted by user')
			
			Store.addAuditTrailRecord(userAddress, consumerAddress, AuditTrail.getShard(now), now, featureId, reason)
			
			ok(payload)
		}

		def static String validateCurrent(byte[] userAddress) {
			NEO.Address.validateCurrent(userAddress)
		}
		
		def static String validate(byte[] userAddress) {
			NEO.Address.validate(userAddress)
		}
	}
	
	
	// STORAGE /////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	static class Store {
		/**
		 * Store feature at compound key: userAddress + featureId. 
		 */
		def static void putFeature(byte[] userAddress, String featureId, byte[] payload) {
			val key = StorageKeys.feature(userAddress, featureId)
			Storage.put(Storage.currentContext, key, payload)
		}
		
		/**
		 * Get feature at compound key: userAddress + featureId. 
		 */
		def static byte[] getFeature(byte[] userAddress, String featureId) {
			val key = StorageKeys.feature(userAddress, featureId)
			Storage.get(Storage.currentContext, key)
		}
		
		/**
		 * Delete feature at compound key: userAddress + featureId. 
		 */
		def static void deleteFeature(byte[] userAddress, String featureId) {
			val key = StorageKeys.feature(userAddress, featureId)
			Storage.delete(Storage.currentContext, key)
		}
		
		/**
		 * Store grant at compound key: consumerAddress + userAddress + featureId. 
		 */
		def static void putGrant(byte[] consumerAddress, byte[] userAddress, String featureId, String license, BigInteger issued, BigInteger expiry, byte[] consumerPubKey, byte[] payload) {
			val key = StorageKeys.grant(consumerAddress, userAddress, featureId)
			val serialized = serialize(license.asByteArray, issued.asByteArray, expiry.asByteArray, consumerPubKey, payload)
			Storage.put(Storage.currentContext, key, serialized)
		}
		
		/**
		 * Get grant at compound key: consumerAddress + userAddress + featureId. 
		 */
		def static byte[][] getGrant(byte[] consumerAddress, byte[] userAddress, String featureId) {
			val key = StorageKeys.grant(consumerAddress, userAddress, featureId)
			val serialized = Storage.get(Storage.currentContext, key)
			if (!serialized.isNullOrEmptyByteArray) deserialize(serialized)
			else newArray
		}
		
		/**
		 * Delete grant at compound key: consumerAddress + userAddress + featureId. 
		 */
		def static void deleteGrant(byte[] consumerAddress, byte[] userAddress, String featureId) {
			val key = StorageKeys.grant(consumerAddress, userAddress, featureId)
			Storage.delete(Storage.currentContext, key)
		}
		
		/**
		 * Add new record to the audit trail at compound key: userAddress + consumerAddress + shard. 
		 */
		def static void addAuditTrailRecord(byte[] userAddress, byte[] consumerAddress, BigInteger shard, BigInteger timestamp, String featureId, String reason) {
			val newRecord = serialize(timestamp.asByteArray, featureId.asByteArray, reason.asByteArray)
			
			val key = StorageKeys.auditTrail(userAddress, consumerAddress, shard.asByteArray)
			val existingTrail = Storage.get(Storage.currentContext, key)
			val updatedTrail = if (existingTrail.isNullOrEmptyByteArray) serialize(newRecord) else {
				val deserializedTrail = deserialize(existingTrail)
				serializeAuditTrail(deserializedTrail, newRecord)
			}
			
			Storage.put(Storage.currentContext, key, updatedTrail)
		}
		
		def static byte[] serialize(byte[]... payload) {
			SmartContractExtensions.serialize(payload)
		}
		
		def static byte[][] deserialize(byte[] serialized) {
			SmartContractExtensions.deserialize(serialized)
		}
		
		def static byte[] serializeAuditTrail(byte[][] auditTrail, byte[] newRecord) {
			val updatedTrail = newTwoDimByteArray(auditTrail.length + 1)
			for (var i = 0; i < auditTrail.length; i++) {
				updatedTrail.set(i, auditTrail.get(i))
			}
			updatedTrail.set(auditTrail.length, newRecord)
			serialize(updatedTrail)
		}
		
		static class StorageKeys {
			def static feature(byte[] userAddress, String featureId) {
				userAddress.concat(featureId.asByteArray)
			}
			
			def static grant(byte[] consumerAddress, byte[] userAddress, String featureId) {
				consumerAddress.concat(userAddress).concat(featureId.asByteArray)
			}
			
			def static auditTrail(byte[] userAddress, byte[] consumerAddress, byte[] shard) {
				userAddress.concat(consumerAddress).concat(shard)
			}
		}
	}
	
	static class Util {
		static class Messaging {
			static class Status {
				def static ok() { 'ok'.asByteArray }
				def static error() { 'error'.asByteArray }
			}
			
			def static error(String message) {
				newArray(Status.error, message.asByteArray)
			} 
			
			def static ok(byte[]... payload) {
				val array = newTwoDimByteArray(payload.length + 1)
				array.set(0, Status.ok)
				for (var i = 0; i < payload.length; i++) {
					array.set(i + 1, payload.get(i))
				}
				array
			}
		}

		static class NEO {
			static class Address {
				def static validate(byte[] address) {
					if (address.length !== Size.HASH160) {
						'Invalid address'
					}
				}
				
				def static validateCurrent(byte[] address) {
					validate(address) ?: if (!Runtime.checkWitness(address)) {
						'Invalid invocator'
					}
				}
			}
			
			static class PublicKey {
				def static validate(byte[] pubKey) {
					if (pubKey.length !== Size.PUBKEY) {
						'Invalid public key'
					}
				}
				
				def static validateCurrent(byte[] pubKey) {
					validate(pubKey) ?: if (!Runtime.checkWitness(pubKey)) {
						'Invalid invocator'
					}
				}
			}
			
			def static getTimestamp() {
				Blockchain.getHeader(Blockchain.height).timestamp.intToBigInteger
			}
			
			static class Size {
				val public static TIMESTAMP = 4
				val public static HASH160 = 20
				val public static PUBKEY = 33
			}
		}
	}
}
