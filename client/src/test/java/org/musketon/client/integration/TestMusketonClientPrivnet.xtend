package org.musketon.client.integration

import de.oehme.xtend.contrib.Cached
import java.io.FileInputStream
import java.nio.file.Paths
import java.util.Properties
import org.junit.BeforeClass
import org.junit.Test
import org.musketon.client.MusketonClient
import org.musketon.client.NEO
import org.musketon.client.Neon
import org.musketon.client.TestMusketonClient
import org.musketon.client.Util

import static org.musketon.client.MusketonClientTestResources.*
import static org.musketon.client.cli.MusketonCLI.*

/** 
 * Same tests as TestMusketonClient, but using a real NEO private net. 
 * Being able to run these tests therefore depends on your local.properties file using the right settings.
 * <p>NOTE: in order to run this, you need enough gas in your private net on the alice and bob accounts.
 */
class TestMusketonClientPrivnet extends TestMusketonClient {
	
	@Cached
	override MusketonClient musketonAlice() {
		new MusketonClient(privnetNeo(ALICE_WIF), alice) => [
			awaitConfirmations = 2
			debug = true
		]
	}
	
	@Cached
	override MusketonClient musketonBob() {
		new MusketonClient(privnetNeo(BOB_WIF), bob) => [
			awaitConfirmations = 2
			debug = true
		]
	}
	
	@BeforeClass
	def static void setup() {
		TestMusketonClient.setup
		Util.MOCKED = false
	}
	
	def NEO privnetNeo(String wif) {
		val localProperties = new Properties
		localProperties.load(new FileInputStream(Paths.get('..', 'local.properties').toString))
		
		val net = localProperties.getProperty(PROPERTY_NET)
		val scriptHash = localProperties.getProperty(PROPERTY_SCRIPT_HASH)
		val nodeJs = localProperties.getProperty(PROPERTY_NODE_JS_UNIX) ?: localProperties.getProperty(PROPERTY_NODE_JS_WINDOWS) ?: '/usr/local/bin/node'
		val scriptsPath = 'src/main/neon'
		
		println('''net: «net»''')
		println('''scriptHash: «scriptHash»''')
		println('''nodeJs: «nodeJs»''')
		println('''scriptsPath: «scriptsPath»''')
		
		if (#[ net, scriptHash, nodeJs ].exists [ nullOrEmpty ]) 
			throw new Exception('Incomplete local.properties to be able to work with Neon')
		
		new Neon(net, scriptHash, wif, nodeJs, scriptsPath) => [ 
			debug = true
			printCommands = true
		]
	}
	
	@Test
	override testFeatureCRUD() {
		super.testFeatureCRUD
	}
	
	@Test
	override testGrants() {
		super.testGrants
	}
	
	@Test
	override testFeatureExchange() {
		super.testFeatureExchange
	}
}
