package org.musketon.client.cli

import org.apache.commons.cli.Options

interface Command {
	def Command getParent()
	
	/** The CLI options for this command */
	def Options getCommandOptions() {
		new Options
	}
	
	/** The recursive CLI options for the full command */
	def Options getOptions() {
		new Options => [
			parent?.options?.options?.forEach [ opt | addOption(opt) ]
			this.commandOptions.options.forEach [ opt | addOption(opt) ]
		]
	}
	
	def String getCommandName() {
		class.simpleName.toLowerCase
	}
	
	def String getDescription() {
		null
	}
	
	def String getArgName() { 
		null
	}
	
	def String getArgDesc() { 
		null
	}
	
	def Command[] getSubcommands() { 
		emptyList
	}
	
	def void execute(String... args) {
		val command = args.head
		val subcommand  = subcommands.findFirst [ commandName == command ]
		if (subcommand !== null) {
			if (subcommand.checkHelpOption && args.containsHelp && subcommand.subcommands.empty) {
				subcommand.printHelp
			} else {
				subcommand.execute(args.tail)
			}
		} else {
			printHelp
		}
	}
	
	def boolean checkHelpOption() {
		true
	}
	
	def boolean containsHelp(String[] args) {
		args.contains('--help') || args.contains('-help')
	}
	
	def void printHelp(Command command) {
		printHelp(command, command.options)
	}
	
	def void printHelp(Command command, Options options) {
		parent?.printHelp(command, options)
	}
	
	def Command[] getRecursiveCommands() {
		val sucommands = subcommands
		if (sucommands.empty) #[ this ]
		else subcommands.map [ recursiveCommands.toList ].flatten
	}
	
	def String getFullCommandName() {
		#[ parent?.fullCommandName, commandName ].filterNull.join(' ')
	}
	
	def String getFormattedCommandName() {
		if (argName.nullOrEmpty) fullCommandName
		else '''«fullCommandName» <«argName»>'''
	}
	
	def String enumDesc(String... values) {
		if (!values.empty)
			'''Can be: [ «values.join(' | ')» ]'''
	}
}
