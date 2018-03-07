package org.musketon.client

import com.google.common.base.Charsets
import com.google.common.io.CharStreams
import java.io.InputStreamReader
import java.nio.file.Paths
import java.time.Duration
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.musketon.client.NEO.Account.AddressAccount
import org.musketon.client.NEO.Account.PrivateKeyAccount
import org.musketon.client.NEO.Account.PublicKeyAccount

import static extension org.musketon.client.Crypto.*
import static extension org.musketon.client.Util.*

@FinalFieldsConstructor
@Accessors(PUBLIC_GETTER)
class Neon implements NEO {
	val String net
	val String contractScriptHash
	val String wif
	
	val String nodePath
	val String scriptsPath
	
	@Accessors(PUBLIC_SETTER)
	boolean debug = false
	
	@Accessors(PUBLIC_SETTER)
	boolean printCommands = false
	
	@Accessors(PUBLIC_SETTER)
	int invocationRetries = 5
	
	@Accessors(PUBLIC_SETTER)
	Duration retryInterval = Duration.ofSeconds(15)
	
	String balance = '{}'
	
	override invoke(String operation, InvocationArg... args) {
		invoke(operation, args, balance, invocationRetries)
	}
	
	def protected String invoke(String operation, InvocationArg[] args, String balance, int retries) {
		try {
			val response = doInvoke(balance, operation, args).split('\n')
			this.balance = response.head
			response.last
		} catch(Exception e) {
			val retriesLeft = retries - 1
			if (debug) {
				println(e.message)
				println('''Retrying invocation («retriesLeft» retries left)''')
			}
			if (retriesLeft > 0) {
				Thread.sleep(retryInterval.toMillis)
				invoke(operation, args, '{}', retriesLeft)
			} else throw e
		}
	}
	
	def protected String doInvoke(String balance, String operation, InvocationArg[] args) {
		neon('invoke', #[ net, wif, balance, contractScriptHash, operation ] + args.map [ 
			#[ type, switch it:value {
				byte[]: toStringHex
				default: toString
			}]
		].flatten)
	}
	
	override getConfirmations(String txId) {
		val result = neon('tx-confirmation', #[ net, txId ])
		if (!result.nullOrEmpty) Integer.parseInt(result)
		else 0
	}
	
	override getStorage(byte[] key) {
		val result = neon('getstorage', #[ net, contractScriptHash, key.toStringHex ]).trim
		if (!result.isNullOrEmpty) result.toByteArrayHex
	}
	
	def static isNullOrEmpty(String jsString) {
		jsString === null || jsString.empty || jsString == 'null' || jsString == 'undefined' 
	}
	
	override getAccountFromWif(String wif) {
		getAccountFromKey(wif) as PrivateKeyAccount
	}
	
	override getAccountFromPublicKey(byte[] publicKey) {
		getAccountFromKey(publicKey.toStringHex) as PublicKeyAccount
	}
	
	override getAccountFromAddress(String address) {
		getAccountFromKey(address) as AddressAccount
	}
	
	def Account getAccountFromKey(String key) {
		val accountValues = neon('account', #[ key ]).split('\n')
		
		val address = accountValues.get(0)
		val addressBytes = accountValues.get(1).toByteArrayHex
		val publicKeyValue = accountValues.get(2)
		val publicKeyUncompressedValue = accountValues.get(3)
		val privateKeyValue = accountValues.get(4)
		
		val publicKeyBytes = if (!publicKeyValue.nullOrEmpty) publicKeyValue.toByteArrayHex
		val publicKeyUncompressedBytes = if (!publicKeyUncompressedValue.nullOrEmpty) publicKeyUncompressedValue.toByteArrayHex
		val privateKeyBytes = if (!privateKeyValue.nullOrEmpty) privateKeyValue.toByteArrayHex
		
		val publicKey = if (publicKeyUncompressedBytes !== null) publicKeyUncompressedBytes.publicKey
		val privateKey = if (privateKeyBytes !== null) privateKeyBytes.privateKey
		
		if (privateKey !== null && publicKey !== null) {
			new PrivateKeyAccount(address, addressBytes, publicKey, publicKeyBytes, publicKeyUncompressedBytes, privateKey, privateKeyBytes)
		} else if (publicKey !== null) {
			new PublicKeyAccount(address, addressBytes, publicKey, publicKeyBytes, publicKeyUncompressedBytes)
		} else {
			new AddressAccount(address, addressBytes)
		} 
	}
	
	def neon(String script, String[] args) {
		val scriptLocation = Paths.get(scriptsPath, '''«script».js''').toString
		val command = #[ nodePath, scriptLocation ] + args
		if (printCommands) println(command.join(' '))
		exec(command)
	}
	
	def static exec(String... command) {
		val process = new ProcessBuilder(command).start
		process.waitFor
		
		val error = CharStreams.toString(new InputStreamReader(process.errorStream, Charsets.UTF_8))
		if (!error.nullOrEmpty) throw new Exception(error.trim)
		
		val result = CharStreams.toString(new InputStreamReader(process.inputStream, Charsets.UTF_8))
		
		result.trim
	}
}