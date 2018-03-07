package org.musketon.client

import java.security.PrivateKey
import java.security.PublicKey
import org.eclipse.xtend.lib.annotations.Data
import org.musketon.client.NEO.Account.PublicKeyAccount
import org.musketon.client.NEO.Account.PrivateKeyAccount
import org.musketon.client.NEO.Account.AddressAccount

interface NEO {
	def String invoke(String operation, InvocationArg... args)
	
	def Integer getConfirmations(String txId)
	
	def byte[] getStorage(byte[] key)
	
	def AddressAccount getAccountFromAddress(String address)
	def PublicKeyAccount getAccountFromPublicKey(byte[] publicKey)
	def PrivateKeyAccount getAccountFromWif(String wif)
	
	@Data
	static class InvocationArg {
		String type
		Object value
	}
	
	static class Account {
		@Data
		static class AddressAccount extends Account {
			val String address
			val byte[] addressBytes
		}
		
		@Data
		static class PublicKeyAccount extends AddressAccount {
			val PublicKey publicKey
			val byte[] publicKeyBytes
			val byte[] publicKeyUncompressedBytes
		}
		
		@Data
		static class PrivateKeyAccount extends PublicKeyAccount {
			val PrivateKey privateKey
			val byte[] privateKeyBytes
		}
	}
}
