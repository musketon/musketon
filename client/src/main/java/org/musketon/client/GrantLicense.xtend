package org.musketon.client

import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import org.apache.commons.text.WordUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.musketon.Musketon
import org.musketon.client.Messages.Grant

import static org.musketon.client.Util.*

@FinalFieldsConstructor
@Accessors(PUBLIC_GETTER)
class GrantLicense {
	val String type
	
	val public static READ = new GrantLicense('read')
	
	def generateLicense(String userAddress, String featureId, Grant grant) {
		switch type {
			case READ.type: Generator.generateReadLicense(userAddress, grant.consumer, featureId, Instant.ofEpochSecond(grant.expiry))
		}
	}
	
	static class Generator {
		def static String generateReadLicense(String userAddress, String consumerAddress, String featureId, Instant expiry) {
			generateLicense (
				licenseIntro(userAddress, consumerAddress, featureId, expiry),
				consumerMayInvoke, 
				consumerShallNotStore,
				consumerShouldProvideDescription,
				userMayRevoke
			)
		}
		
		def protected static String generateLicense(String... components) {
			stringBuilder [
				append(heading)
				append('\n')
				
				append(components.map [ removeSpacing.format ].join('\n\n'))
			]		
		}
		
		val static FORMATTER = DateTimeFormatter.RFC_1123_DATE_TIME.withZone(ZoneOffset.UTC)
		
		def static String licenseIntro(String userAddress, String consumerAddress, String feature, Instant expiry) {
			'''
				Permission is hereby granted for address owner («consumerAddress»), hereinafter referred to as the 'consumer', 
				to 'read' feature '«feature»' of address owner («userAddress»), hereinafter referred to as the 'user', 
				until: «if (expiry.epochSecond == Musketon.User.Grant.INDEFINITE_EXPIRY) 'indefinite' else FORMATTER.format(expiry)». 
			'''
		}
		
		def static String consumerShouldProvideDescription() {
			'''
				The consumer SHOULD on every 'read' request provide a brief description on why the request was done
				and SHALL only use the granted data for the specified purpose. 
			'''
		}
		
		def static String consumerMayInvoke() {
			'''
				Within this period of time, the consumer MAY invoke a 'read' request to Musketon to retrieve the user's data. 
				The consumer SHALL only use the offical Musketon client to do this.
			'''
		}
		
		def static String consumerShallNotStore() {
			'''
				The consumer SHALL NOT store the granted feature to disk, with the exception of –if really necessary– caching it for a maximum period of 12 hours.
				To access it again will require a new 'read' invocation.
			'''
		}
		
		def static String userMayRevoke() {
			'''
				The user MAY at any arbitrary time and for any arbitrary, undiclosed reason choose to revoke the grant and thereby terminate this agreement, 
				causing any future 'read' requests done by the consumer to fail. 
			'''
		}
		
		def static removeSpacing(CharSequence text) {
			text.toString.replace('\n', ' ').replace('  ', ' ')
		}
		
		def static String heading() {
			'''
				MUSKETON GRANT LICENSE - READ
				---
			'''
		}
		
		val static MAX_LINE_LENGTH = 90
		
		def static String format(String license) {
			WordUtils.wrap(license, MAX_LINE_LENGTH)
		}
	}
}