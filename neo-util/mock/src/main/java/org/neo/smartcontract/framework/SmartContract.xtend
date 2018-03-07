package org.neo.smartcontract.framework

class SmartContract {
	def protected native static byte[] sha1(byte[] data) 
	
	def protected native static byte[] sha256(byte[] data) 
	
	def protected native static byte[] hash160(byte[] data) 
	
	def protected native static byte[] hash256(byte[] data) 
	
	def protected native static boolean verifySignature(byte[] signature, byte[] pubkey) 
	
	def protected native static boolean verifySignatures(byte[][] signature, byte[][] pubkey) 
}