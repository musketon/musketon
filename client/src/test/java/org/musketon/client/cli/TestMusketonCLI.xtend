package org.musketon.client.cli

import de.oehme.xtend.contrib.Cached
import java.io.ByteArrayOutputStream
import java.io.PrintStream
import java.util.Properties
import org.apache.commons.cli.CommandLine
import org.apache.commons.cli.Option
import org.apache.commons.cli.ParseException
import org.junit.After
import org.junit.BeforeClass
import org.junit.Test
import org.musketon.client.GrantLicense
import org.musketon.client.MusketonClient
import org.musketon.client.MusketonClientTestResources
import org.musketon.client.Util

import static org.junit.Assert.*
import static org.musketon.client.MusketonClientTestResources.*
import static org.musketon.client.cli.MusketonCLI.*

import static extension org.musketon.client.Util.*

class TestMusketonCLI {
	
	def aliceCLI() {
		musketonAlice.cli
	}
	
	def bobCLI() {
		musketonBob.cli
	}
	
	def getCli(MusketonClient musketon) {
		new MusketonTestCLI(musketon)
	}
	
	static class MusketonTestCLI extends MusketonCLI {
		val MusketonClient musketon
		
		new(MusketonClient musketon) {
			super(new Properties)
			this.musketon = musketon
		}
		
		override getMusketonClient(CommandLine command) {
			musketon
		}
		
		def executeAndPrint(String command) {
			println('---')
			println(command)
			println('---')
			var Exception exception
			try execute(command.split(' ').map [ toString ]) catch(Exception e) exception = e
			val result = #[ outStream.toString, errStream.toString ].filter [ !nullOrEmpty ].join('\n') 
			println(result)
			if (exception !== null) throw exception
			result
		}
		
		@Cached
		override PrintStream getOut() {
			new PrintStream(outStream)
		}
		
		@Cached
		override PrintStream getErr() {
			new PrintStream(errStream)
		}
		
		@Cached
		def ByteArrayOutputStream getOutStream() {
			new ByteArrayOutputStream
		}
		
		@Cached
		def ByteArrayOutputStream getErrStream() {
			new ByteArrayOutputStream
		}
	}
	
	def getCli() {
		aliceCLI
	}
	
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
	def void testPrintHelp() {
		val featureCommands = #[ 
			'musketon feature define <feature id>',
			'musketon feature get <feature id>',
			'musketon feature delete <feature id>'
		]
		
		val grantCommands = #[
			'musketon grant authorize <feature id>',
			'musketon grant get <feature id>',
			'musketon grant revoke <feature id>'
		]
		
		val consumerCommands = #[
			'musketon consumer read <feature id>'
		]
		
		val auditTrailCommands = #[
			'musketon audittrail'
		]
		
		cli.executeAndPrint('')
			.asssertPrintsHelp(featureCommands + grantCommands + consumerCommands + auditTrailCommands, OPTION_ME)
		
		cli.executeAndPrint('feature')
			.asssertPrintsHelp(featureCommands, OPTION_ME)
		
		cli.executeAndPrint('grant')
			.asssertPrintsHelp(grantCommands, OPTION_ME)
		
		cli.executeAndPrint('consumer')
			.asssertPrintsHelp(consumerCommands, OPTION_ME)
		
		cli.executeAndPrint('audittrail --help')
			.asssertPrintsHelp(auditTrailCommands, OPTION_ME)
		
		cli.executeAndPrint('feature define name --help')
			.asssertPrintsHelp(#[ 'musketon feature define <feature id>' ], OPTION_ME)
	}
	
	@Test
	def void testFeatureCRUD() {
		assertThrows(Exception) [ cli.executeAndPrint('''feature define''') ]
		assertThrows(Exception) [ cli.executeAndPrint('''feature define non_existing_feature''') ]
		assertThrows(Exception) [ cli.executeAndPrint('''feature define --me «ALICE_WIF»''') ]
		
		assertThrows(ParseException) [ cli.executeAndPrint('''feature define birthdate''') ]
		assertThrows(ParseException) [ cli.executeAndPrint('''feature define birthdate --me «ALICE_WIF» --year «FEATURE_BIRTHDATE.year»''') ]
		
		val getEmpty = cli.executeAndPrint('''feature get birthdate --me «ALICE_WIF»''')
		assertEquals('null\n', getEmpty)
		
		val defineLongOpt = cli.executeAndPrint('''feature define birthdate --me «ALICE_WIF» --year «FEATURE_BIRTHDATE.year» --month «FEATURE_BIRTHDATE.month» --day «FEATURE_BIRTHDATE.day»''')
		assertEquals(FEATURE_BIRTHDATE.toString, defineLongOpt)
		
		val defineShortOpt = cli.executeAndPrint('''feature define birthdate --me «ALICE_WIF» -y «FEATURE_BIRTHDATE.year» -m «FEATURE_BIRTHDATE.month» -d «FEATURE_BIRTHDATE.day»''')
		assertEquals(FEATURE_BIRTHDATE.toString, defineShortOpt)
		
		val get = cli.executeAndPrint('''feature get birthdate --me «ALICE_WIF»''')
		assertEquals(FEATURE_BIRTHDATE.toString, get)
		
		val delete = cli.executeAndPrint('''feature delete birthdate --me «ALICE_WIF»''')
		assertEquals('', delete)
	}
	
	@Test
	def void testGrants() {
		assertThrows(Exception) [ cli.executeAndPrint('''grant authorize''') ]
		assertThrows(Exception) [ cli.executeAndPrint('''grant authorize non_existing_feature''') ]
		assertThrows(Exception) [ cli.executeAndPrint('''grant authorize --me «ALICE_WIF»''') ]
		
		assertThrows(ParseException) [ cli.executeAndPrint('''grant authorize birthdate''') ]
		assertThrows(ParseException) [ cli.executeAndPrint('''grant authorize birthdate --me «ALICE_WIF»''') ]
		assertThrows(ParseException) [ cli.executeAndPrint('''grant authorize birthdate --me «ALICE_WIF» --consumer «bob.publicKeyBytes.toStringHex»''') ]
		assertThrows(Exception) [ cli.executeAndPrint('''grant authorize birthdate --me «ALICE_WIF» --consumer «bob.address» --indefinite''') ]
		
		val getEmpty = cli.executeAndPrint('''grant get birthdate --me «ALICE_WIF» --consumer «bob.publicKeyBytes.toStringHex»''')
		assertEquals('null\n', getEmpty)
		val getLicenseEmpty = cli.executeAndPrint('''grant get birthdate --me «ALICE_WIF» --consumer «bob.publicKeyBytes.toStringHex» --license''')
		assertEquals('null\n', getLicenseEmpty)
		
		val authorizeLongOpt = cli.executeAndPrint('''grant authorize birthdate --me «ALICE_WIF» --consumer «bob.publicKeyBytes.toStringHex» --indefinite''')
		assertTrue(authorizeLongOpt.contains(bob.address))
		assertTrue(authorizeLongOpt.contains('read'))
		
		val authorizeShortOpt = cli.executeAndPrint('''grant authorize birthdate --me «ALICE_WIF» -c «bob.publicKeyBytes.toStringHex» -e 0''')
		assertTrue(authorizeShortOpt.contains(bob.address))
		assertTrue(authorizeShortOpt.contains('read'))
		
		val get = cli.executeAndPrint('''grant get birthdate --me «ALICE_WIF» --consumer «bob.publicKeyBytes.toStringHex»''')
		assertTrue(get.contains(bob.address))
		assertTrue(get.contains('read'))
		assertTrue(!get.contains('expiry'))
		
		val getLicense = cli.executeAndPrint('''grant get birthdate --me «ALICE_WIF» --consumer «bob.publicKeyBytes.toStringHex» --license''')
		assertTrue(getLicense.startsWith(GrantLicense.Generator.heading))
		
		val revoke = cli.executeAndPrint('''grant revoke birthdate --me «ALICE_WIF» --consumer «bob.publicKeyBytes.toStringHex»''')
		assertEquals('', revoke)
	}
	
	@Test
	def void testConsumer() {
		assertThrows(Exception) [ bobCLI.executeAndPrint('''consumer read''') ]
		assertThrows(Exception) [ bobCLI.executeAndPrint('''consumer read non_existing_feature''') ]
		assertThrows(Exception) [ bobCLI.executeAndPrint('''consumer read --me «BOB_WIF»''') ]
		
		assertThrows(ParseException) [ bobCLI.executeAndPrint('''consumer read birthdate''') ]
		assertThrows(ParseException) [ bobCLI.executeAndPrint('''consumer read birthdate --me «BOB_WIF»''') ]
		
		aliceCLI.executeAndPrint('''feature define birthdate --me «ALICE_WIF» -y «FEATURE_BIRTHDATE.year» -m «FEATURE_BIRTHDATE.month» -d «FEATURE_BIRTHDATE.day»''')
		
		val reason = 'birthday_gift_shopping'
		val readEmpty = bobCLI.executeAndPrint('''consumer read birthdate.birthday --me «BOB_WIF» --user «alice.publicKeyBytes.toStringHex» --reason «reason»''')
		assertEquals('null\n', readEmpty)
		
		aliceCLI.executeAndPrint('''grant authorize birthdate.birthday --me «ALICE_WIF» --consumer «bob.publicKeyBytes.toStringHex» --indefinite''')
		
		val read = bobCLI.executeAndPrint('''consumer read birthdate.birthday --me «BOB_WIF» --user «alice.publicKeyBytes.toStringHex» --reason «reason»''')
		assertEquals(FEATURE_BIRTHDAY.toString, read)
		
		val auditTrail = aliceCLI.executeAndPrint('''audittrail --me «ALICE_WIF» --consumer «bob.publicKeyBytes.toStringHex»''')
		assertTrue(auditTrail.contains(bob.address))
		assertTrue(auditTrail.contains('records'))
	}
	
	def static asssertPrintsHelp(String output, String[] commands, Option... options) {
		assertTrue(output.contains('Usage:'))
		assertTrue(commands.forall [ output.contains(it) ])
		assertTrue(options.forall [ output.contains(longOpt) ]) 
	}
	
	def static assertThrows(Class<? extends Exception> exceptionClass, =>void operation) {
		assertTrue(try { operation.apply false } catch(Exception e) { exceptionClass.isAssignableFrom(e.class) })
	}
}