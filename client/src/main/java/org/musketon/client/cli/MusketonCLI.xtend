package org.musketon.client.cli

import com.google.common.base.CaseFormat
import de.oehme.xtend.contrib.Cached
import java.io.FileInputStream
import java.io.PrintStream
import java.io.PrintWriter
import java.nio.file.Paths
import java.time.Duration
import java.time.Instant
import java.time.Year
import java.util.Map
import java.util.Properties
import org.apache.commons.cli.CommandLine
import org.apache.commons.cli.DefaultParser
import org.apache.commons.cli.HelpFormatter
import org.apache.commons.cli.Option
import org.apache.commons.cli.OptionGroup
import org.apache.commons.cli.Options
import org.apache.commons.cli.ParseException
import org.apache.commons.lang3.SystemUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.musketon.client.Crypto
import org.musketon.client.FeatureSpecs
import org.musketon.client.FeatureSpecs.AddressSpec
import org.musketon.client.FeatureSpecs.BirthdateSpec
import org.musketon.client.FeatureSpecs.NameSpec
import org.musketon.client.FeatureSpecs.Spec
import org.musketon.client.Messages.Address
import org.musketon.client.Messages.Birthdate
import org.musketon.client.Messages.Name
import org.musketon.client.MusketonClient
import org.musketon.client.Neon

import static extension org.musketon.client.Util.*

@Accessors(PUBLIC_GETTER)
class MusketonCLI implements Command {
	
	def static void main(String[] args) {
		val properties = new Properties
		val propertiesPath = path(programRoot, 'musketon.properties')
		properties.load(new FileInputStream(propertiesPath))
		
		Crypto.load
		
		val musketon = new MusketonCLI(properties)
		try {
			musketon.execute(args)
		} catch(Exception e) {
			musketon.printError(e)
			System.exit(1)
		}
	}
	
	val Properties properties
	
	new(Properties properties) {
		this.properties = properties
	}
	
	val public static OPTION_ME = option('me', 'me', 'wif', 'Your NEO WIF').required.build
	val public static OPTION_HELP = option('help', 'help', null, 'Show command usage').build
	val public static OPTION_DEBUG = option('debug', 'debug', null, 'Show more logging').build
	val public static OPTION_VERSION = option('version', 'version', null, 'Show application version').build
	
	val public static PROPERTY_NET = 'musketon.net'
	val public static PROPERTY_SCRIPT_HASH = 'musketon.contract.scriptHash'
	val public static PROPERTY_NODE_JS_UNIX = 'musketon.neon.nodejs.unix'
	val public static PROPERTY_NODE_JS_WINDOWS = 'musketon.neon.nodejs.windows'
	val public static PROPERTY_SCRIPTS_PATH = 'musketon.neon.scripts'
	
	@Accessors(PUBLIC_SETTER)
	boolean debug = false
	
	val commandName = 'musketon'
	val commandOptions = #[ OPTION_ME, OPTION_HELP, OPTION_DEBUG ].options
	val Command parent = null
	
	@Cached
	override Command[] getSubcommands() {
		#[ new Feature(this, this), new Grant(this, this), new AuditTrail(this, this), new Consumer(this, this) ]
	}
	
	override printHelp(Command command, Options options) {
		val writer = new PrintWriter(err)
		new HelpFormatter => [ 
			width = 100
			val indent = '   '
			
			if (command.description !== null) {
				printWrapped(writer, width, 0, 'Description:')
				printWrapped(writer, width, indent.length, indent + command.description)
				printWrapped(writer, width, 0, '')
			}
			
			printWrapped(writer, width, 0, 'Usage:')
			command.recursiveCommands.map [ formattedCommandName ].forEach [ commandName |
				printWrapped(writer, width, 0, indent + commandName)
			]
			
			if (!command.argName.nullOrEmpty) {
				printWrapped(writer, width, 0, '')
				printWrapped(writer, width, 0, 'Parameters:')
				printWrapped(writer, width, 0, indent + '''<«command.argName»>  «command.argDesc»''')
			}
			
			if (command instanceof FeatureIdCommand) {
				printWrapped(writer, width, 0, '')
				printWrapped(writer, width, 0, 'Features:')
				command.supportedFeatures.forEach [ feature |
					printWrapped(writer, width, 0, indent + '''* «feature»''')
				]
			}
			
			printWrapped(writer, width, 0, '')
			printWrapped(writer, width, 0, 'Options:')
			printOptions(writer, width, options, 3, 4)	
		]
		writer.flush		
	}
	
	def PrintStream getOut() {
		System.out
	}
	
	def PrintStream getErr() {
		System.err
	}
	
	def void printSuccess(Object... objects) {
		out => [
			objects.forEach [ obj |
				if (debug) println('============================== SUCCESS ==============================')
				println(obj?.toString?.trim)
			]
		]
	}
	
	def void printError(Exception error) {
		err => [
			println
			println('============================== ERROR ==============================')
			if (debug) error.printStackTrace
			else println(error.message ?: error.class.simpleName)
			println
		]
	}
	
	def parse(Command command, Options options, String[] args) {
		try new DefaultParser().parse(options, args) catch(ParseException e) {
			printHelp(command, options)
			throw e
		}
	}
	
	def parseCommandArg(Command command, String[] args) {
		val param = args.head
		if (args.empty || param.startsWith('-')) {
			printHelp(command)
			throw new ParseException('''Missing command arg <«command.argName»>''')
		}
		param
	}
	
	def parseFeatureId(FeatureIdCommand command, String[] args) {
		val featureId = command.parseCommandArg(args)
		try {
			val spec = FeatureSpecs.getSpec(featureId)
			if (!command.supportedFeatures.contains(featureId))
				throw new IllegalArgumentException('''It's not possible to «command.commandName» feature «featureId»''')
			
			featureId -> spec
		}
		catch(Exception e) {
			printHelp(command)
			throw e
		}
	}
	
	def getMusketonClient(CommandLine command) {
		val net = properties.getProperty(PROPERTY_NET)
		val scriptHash = properties.getProperty(PROPERTY_SCRIPT_HASH)
		val nodeJsProperty = if (SystemUtils.IS_OS_WINDOWS) PROPERTY_NODE_JS_WINDOWS else PROPERTY_NODE_JS_UNIX 
		val nodeJs = properties.getProperty(nodeJsProperty)
		val scriptsPath = properties.getProperty(PROPERTY_SCRIPTS_PATH) ?: scriptsPath
		
		if (#[ net, scriptHash, nodeJs, scriptsPath ].exists [ nullOrEmpty ]) 
			throw new Exception('Incomplete properties')
		
		val wif = command.getOptionValue(OPTION_ME.opt)
		val debug = command.hasOption(OPTION_DEBUG.opt)
		
		val neo = new Neon(net, scriptHash, wif, nodeJs, scriptsPath)
		val account = neo.getAccountFromWif(wif)
		
		val musketon = new MusketonClient(neo, account)
		musketon.awaitConfirmations = 2
		
		neo.debug = debug
		musketon.debug = debug
		this.debug = debug
		
		musketon
	}
	
	@FinalFieldsConstructor
	@Accessors(PUBLIC_GETTER)
	static class Feature implements Command {
		val extension MusketonCLI root
		val Command parent
		
		@Cached
		override Command[] getSubcommands() {
			 #[ new Feature.Define(root, this), new Feature.Get(root, this), new Feature.Delete(root, this) ]
		}
		
		@FinalFieldsConstructor
		@Accessors(PUBLIC_GETTER)
		static class Define implements FeatureIdCommand {
			val extension MusketonCLI root
			val Command parent
			
			val description = 'Define a feature. None of the fields are required.'
			
			val public static OPTION_PARTIAL = option('partial', 'partial', null, 'Skip incomplete definition warning').build
			val commandOptions = #[ OPTION_PARTIAL ].options
			
			val supportedFeatures = FeatureSpecs.definableFeatures
			
			override checkHelpOption() {
				false
			}
			
			override execute(String... args) {
				val featureId = try parseFeatureId(args) catch(Exception e) {
					if (args.containsHelp) return;
					throw e
				}
				
				val spec = featureId.value
				
				val featureOpts = spec.featureOptions
				val options = options.concat(featureOpts.values)
				
				if (args.containsHelp) {
					printHelp(options)
					return
				}
				
				val extension line = parse(options, args)
				
				if (!hasOption(OPTION_PARTIAL.opt)) {
					val missingFeatureFields = featureOpts.values.filter [ !line.hasOption(longOpt) ]
					if (!missingFeatureFields.empty) { /** TODO: add flag to options to allow partial entry */
						val message = '''
							Incomplete feature entry, missing options: «missingFeatureFields.map [ longOpt ].join(', ')». 
							To dismiss this check, add the --partial flag.
						'''
						printHelp(options)
						throw new ParseException(message)
					}
				}
				
				val musketon = getMusketonClient(line)
				val feature = musketon.execute(line, featureOpts, spec)
				printSuccess(feature)
			}
			
			def dispatch execute(MusketonClient musketon, extension CommandLine line, Map<String, Option> featureOpts, NameSpec spec) {
				val firstName = getOptionValue(featureOpts.get(spec.firstName).longOpt)
				val lastName = getOptionValue(featureOpts.get(spec.lastName).longOpt)
				
				val b = Name.newBuilder
				if (firstName !== null) b.setFirstName(firstName)
				if (lastName !== null) b.setLastName(lastName)
				val name = b.build
				
				musketon.user.defineName(name)
				name
			}
			
			def dispatch execute(MusketonClient musketon, extension CommandLine line, Map<String, Option> featureOpts, BirthdateSpec spec) {
				val year = getOptionValue(featureOpts.get(spec.year).longOpt)?.parseInt
				val month = getOptionValue(featureOpts.get(spec.month).longOpt)?.parseInt
				val day = getOptionValue(featureOpts.get(spec.day).longOpt)?.parseInt
				
				val b = Birthdate.newBuilder
				if (year !== null) b.setYear(year)
				if (month !== null) b.setMonth(month)
				if (day !== null) b.setDay(day)
				val birthdate = b.build
				
				musketon.user.defineBirthdate(birthdate)
				birthdate
			}
			
			def dispatch execute(MusketonClient musketon, extension CommandLine line, Map<String, Option> featureOpts, AddressSpec spec) {
				val country = getOptionValue(featureOpts.get(spec.country).longOpt)
				val province = getOptionValue(featureOpts.get(spec.province).longOpt)
				val city = getOptionValue(featureOpts.get(spec.city).longOpt)
				val addressLine1 = getOptionValue(featureOpts.get(spec.addressLine1).longOpt)
				val addressLine2 = getOptionValue(featureOpts.get(spec.addressLine2).longOpt)
				val postalCode = getOptionValue(featureOpts.get(spec.postalCode).longOpt)
				
				val b = Address.newBuilder
				if (country !== null) b.setCountry(country)
				if (province !== null) b.setProvince(province)
				if (city !== null) b.setCity(city)
				if (addressLine1 !== null) b.setAddressLine1(addressLine1)
				if (addressLine2 !== null) b.setAddressLine2(addressLine2)
				if (postalCode !== null) b.setPostalCode(postalCode)
				val address = b.build
				
				musketon.user.defineAddress(address)
				address
			}
			
			@Cached
			def static Map<String, Option> getFeatureOptions(Spec<?> spec) {
				val featureOptions = spec.featureComponents.fold(newHashMap) [ map, it | 
					map.put(it, toFeatureOption) 
					map
				]
				featureOptions.mapValues [ option | 
					/** Remove the short opt when duplicates are detected */
					if (featureOptions.values.filter [ it.opt == option.opt ].size > 1) 
						option(null, option.longOpt, option.argName, option.description).build
					else option
				]
			}
			
			def static toFeatureOption(String featureComponent) {
				val fieldName = featureComponent.split('\\.').last
				val fieldNameSplit = fieldName.split('_')
				val opt = fieldNameSplit.map [ charAt(0) ].join
				val longOpt = CaseFormat.LOWER_UNDERSCORE.to(CaseFormat.LOWER_HYPHEN, fieldName)
				val arg = fieldName.replace('_', ' ')
				val featureGroup = featureComponent.split('\\.').head
				val desc = '''Your «featureGroup»'«IF !featureGroup.endsWith('s')»s«ENDIF» «arg»'''
				option(opt, longOpt, arg, desc).build
			}
		}
		
		@FinalFieldsConstructor
		@Accessors(PUBLIC_GETTER)
		static class Get implements FeatureIdCommand {
			val extension MusketonCLI root
			val Command parent
			
			val description = 'Get a feature you defined. This will be exactly how a granted consumer will also it.'
			
			val supportedFeatures = FeatureSpecs.grantableFeatures
			
			override execute(String... args) {
				val featureId = parseFeatureId(args)
				val line = parse(options, args)
				
				val musketon = getMusketonClient(line)
				val feature = musketon.user.getFeature(featureId.key)
				printSuccess(feature)
			}
		}
		
		@FinalFieldsConstructor
		@Accessors(PUBLIC_GETTER)
		static class Delete implements FeatureIdCommand {
			val extension MusketonCLI root
			val Command parent
			
			val description = 'Delete a feature along with all of its derived features.'
			
			val supportedFeatures = FeatureSpecs.definableFeatures
			
			override execute(String... args) {
				val featureId = parseFeatureId(args)
				val line = parse(options, args)
				
				val musketon = getMusketonClient(line)
				
				musketon.user.deleteFeature(featureId.key)
				printSuccess
			}
		}
	}
	
	@FinalFieldsConstructor
	@Accessors(PUBLIC_GETTER)
	static class Grant implements Command {
		val extension MusketonCLI root
		val Command parent
		
		@Cached
		override Command[] getSubcommands() {
			#[ new Grant.Authorize(root, this), new Grant.Get(root, this), new Grant.Revoke(root, this) ]
		}
		
		@FinalFieldsConstructor
		@Accessors(PUBLIC_GETTER)
		static class Authorize implements FeatureIdCommand {
			val extension MusketonCLI root
			val Command parent
			
			val description = 'Authorize a consumer to read out a certain feature. Use option -e to set the expiry, or add the --indefinite flag.'
			
			val public static OPTION_CONSUMER = option('c', 'consumer', 'public key', 'The NEO public key of the consumer').required.build
			val public static OPTION_EXPIRY = option('e', 'expiry', 'days', 'After how many days the grant should be expire').build
			val public static OPTION_INDEFINITE = option('indefinite', 'indefinite', null, 'Set no expiry for the grant').build
			val commandOptions = #[ OPTION_CONSUMER, OPTION_EXPIRY, OPTION_INDEFINITE ].options
			
			val supportedFeatures = FeatureSpecs.grantableFeatures
			
			override execute(String... args) {
				val featureId = parseFeatureId(args)
				val line = parse(options, args)
				
				val consumerPublicKey = line.getOptionValue(OPTION_CONSUMER.opt).toByteArrayHex
				val expiry = parseExpiry(line)
				
				val musketon = getMusketonClient(line)
				val grant = musketon.user.authorize(consumerPublicKey, featureId.key, expiry)
				printSuccess(grant)
			}
			
			def parseExpiry(CommandLine line) {
				if (!line.hasOption(OPTION_EXPIRY.opt) && !line.hasOption(OPTION_INDEFINITE.longOpt)) {
					val message = '''Either «OPTION_EXPIRY.longOpt» or the «OPTION_INDEFINITE.longOpt» flag must be set'''
					printHelp
					throw new ParseException(message)
				}
				val expiryDays = line.getOptionValue(OPTION_EXPIRY.opt)?.parseInt ?: 0
				val expiry = Duration.ofDays(expiryDays)
				if (expiry == Duration.ZERO) Instant.EPOCH
				else Instant.now.plus(expiry)
			}
		}
		
		@FinalFieldsConstructor
		@Accessors(PUBLIC_GETTER)
		static class Get implements FeatureIdCommand {
			val extension MusketonCLI root
			val Command parent
			
			val description = 'See the grant for a certain consumer and feature, if there is one.'
			
			val public static OPTION_CONSUMER = option('c', 'consumer', 'address or public key', 'The NEO address or public key of the consumer').required.build
			val public static OPTION_LICENSE = option('license', 'license', null, 'Print the grant license').build
			val commandOptions = #[ OPTION_CONSUMER, OPTION_LICENSE ].options
			
			val supportedFeatures = FeatureSpecs.grantableFeatures
			
			override execute(String... args) {
				val featureId = parseFeatureId(args)
				val line = parse(options, args)
				
				val consumerAddress = line.getOptionValue(OPTION_CONSUMER.opt)
				val printAsLicense = line.hasOption(OPTION_LICENSE.opt)
				
				val musketon = getMusketonClient(line)
				if (printAsLicense) {
					val license = musketon.user.getGrantLicense(consumerAddress, featureId.key)
					printSuccess(license)
					return
				}
				
				val grant = musketon.user.getLatestGrant(consumerAddress, featureId.key)
				printSuccess(grant)
			}
		}
		
		@FinalFieldsConstructor
		@Accessors(PUBLIC_GETTER)
		static class Revoke implements FeatureIdCommand {
			val extension MusketonCLI root
			val Command parent
			
			val description = 'Revoke the grant for a certain consumer and feature.'
			
			val public static OPTION_CONSUMER = option('c', 'consumer', 'address or public key', 'The NEO address or public key of the consumer').required.build
			val commandOptions = #[ OPTION_CONSUMER ].options
			
			val supportedFeatures = FeatureSpecs.grantableFeatures
			
			override execute(String... args) {
				val featureId = parseFeatureId(args)
				val line = parse(options, args)
				
				val consumerAddress = line.getOptionValue(OPTION_CONSUMER.opt)
				
				val musketon = getMusketonClient(line)
				musketon.user.revoke(consumerAddress, featureId.key)
				printSuccess
			}
		}
	}
	
	@FinalFieldsConstructor
	@Accessors(PUBLIC_GETTER)
	static class AuditTrail implements Command {
		val extension MusketonCLI root
		val Command parent
		
		val description = 'Get the audit trail of the times that a certain consumer read out your data.'
		
		val public static OPTION_CONSUMER = option('c', 'consumer', 'address or public key', 'The NEO address or public key of the consumer').required.build
		val public static OPTION_YEAR = option('y', 'year', 'year', 'The audit trail for which year to show, defaults to the current year').build
		val commandOptions = #[ OPTION_CONSUMER, OPTION_YEAR ].options
		
		
		override execute(String... args) {
			val line = parse(options, args)
			
			val consumerAddress = line.getOptionValue(OPTION_CONSUMER.opt)
			val year = line.getOptionValue(OPTION_YEAR.opt)?.parseInt ?: Year.now.value
			
			val musketon = getMusketonClient(line)
			val auditTrail = musketon.user.getAuditTrail(consumerAddress, year)
			printSuccess(auditTrail)
		}
	}
		
	@FinalFieldsConstructor
	@Accessors(PUBLIC_GETTER)
	static class Consumer implements Command {
		val extension MusketonCLI root
		val Command parent
		
		override getSubcommands() {
			#[ new Consumer.Read(root, this) ]
		}
		
		@FinalFieldsConstructor
		@Accessors(PUBLIC_GETTER)
		static class Read implements FeatureIdCommand {
			val extension MusketonCLI root
			val Command parent
			
			val description = 'Read out a certain feature of a certain user, given that the user has authorized you and the grant has not yet expired. Every read will be recorded onto the audit trail, for the user to see.'
			
			val public static OPTION_USER = option('u', 'user', 'public key', 'The NEO public key of the user that granted you').required.build
			val public static OPTION_REASON = option('r', 'reason', 'reason', 'A very brief description/keyword on why you\'re requesting this data').build
			val commandOptions = #[ OPTION_USER, OPTION_REASON ].options
			
			val supportedFeatures = FeatureSpecs.grantableFeatures
			
			override execute(String... args) {
				val featureId = parseFeatureId(args)
				val spec = featureId.value
				val featureClass = spec.getFeatureClass(featureId.key)
				val line = parse(options, args)
				
				val userPublicKey = line.getOptionValue(OPTION_USER.opt).toByteArrayHex
				val reason = line.getOptionValue(OPTION_REASON.opt)
				
				val musketon = getMusketonClient(line)
				val grant = musketon.consumer.read(userPublicKey, featureClass, reason)
				printSuccess(grant)
			}
		}
	}
	
	val public static TOP_COMMAND = 'musketon'
	
	def static String fullCommand(Class<?> commandClass) {
		'''«TOP_COMMAND» «commandClass.name.split('\\$').drop(MusketonCLI.name.split('\\$').length).map [ toLowerCase ].join(' ')»'''
	}
	
	def static command(Class<?> commandClass) {
		commandClass.simpleName.toLowerCase
	}
	
	def static String argName(String command, String argName) {
		'''«command» <«argName»>'''
	}
	
	def static String argValue(String command, String argValue) {
		'''«command» «argValue»'''
	}
	
	def static option(String opt, String longOpt, String argName, String desc) {
		Option.builder(opt).longOpt(longOpt).hasArg(argName !== null).argName(argName).desc(desc)
	}
	
	def static options(Option... options) {
		options.fold(new Options) [ it, opt | addOption(opt) ]
	}
	
	def static optionGroup(Option... options) {
		options.fold(new OptionGroup) [ it, opt | addOption(opt) ]
	}
	
	def static concat(Options options, Option... moreOptions) {
		new Options => [
			options.options.forEach [ opt | addOption(opt) ]
			moreOptions.forEach [ opt | addOption(opt) ]
		]
	}
	
	def static parseInt(String string) {
		if (string !== null) Integer.parseInt(string)
		else null
	}
			
	@Cached
	def static String programRoot() {
		var sourcePath = MusketonCLI.protectionDomain.codeSource.location.path
		if (sourcePath.endsWith('jar')) sourcePath = Paths.get(sourcePath, '..').toString
		
		Paths.get(sourcePath, '..').normalize.toString
	}
	
	def static String scriptsPath() {
		path(programRoot, 'lib', 'neon')
	}
}

/** Command that takes a feature id arg */
interface FeatureIdCommand extends Command {
	override getArgName() {
		'feature id'
	}
	
	override getArgDesc() {
		'''The feature to «commandName»'''
	}
	
	def String[] getSupportedFeatures() 
}
