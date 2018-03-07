package org.musketon.client

import com.google.common.collect.HashBiMap
import com.google.protobuf.Message
import com.neovisionaries.i18n.CountryCode
import java.util.List
import java.util.Map
import org.eclipse.xtend.lib.annotations.Accessors
import org.musketon.client.Messages.Address
import org.musketon.client.Messages.Birthdate
import org.musketon.client.Messages.Birthday
import org.musketon.client.Messages.Birthyear
import org.musketon.client.Messages.City
import org.musketon.client.Messages.Country
import org.musketon.client.Messages.FirstName
import org.musketon.client.Messages.Initials
import org.musketon.client.Messages.LastName
import org.musketon.client.Messages.Name

import static extension java.lang.Character.*

class FeatureSpecs {
	interface Spec<MainFeature extends Message> {
		def String getGroup()
		
		def List<String> getFeatureComponents()
		
		def List<String> getGrantableFeatures()
		
		def void validate(MainFeature feature)
		
		def Message[] deriveFeatures(MainFeature feature) {
			emptyList
		}
		
		def Map<String, ? extends Class<? extends Message>> getFeatureTypeMapping()
		
		def <T extends Message> String getFeatureId(T featureClass) {
			getFeatureId(featureClass.class)
		}
	
		def <T extends Message> String getFeatureId(Class<T> featureClass) {
			val featureId = HashBiMap.create(featureTypeMapping).inverse.get(featureClass)
			if (featureId === null) throw new IllegalArgumentException
			featureId
		}
	
		def Class<? extends Message> getFeatureClass(String featureId) {
			val featureClass = featureTypeMapping.get(featureId)
			if (featureClass === null) throw new IllegalArgumentException
			featureClass
		}
		
		def String feature(String feature) {
			#[ group, feature ].join('.')
		}
	}
	
	val public static name = new NameSpec
	val public static birthdate = new BirthdateSpec
	val public static address = new AddressSpec
	
	val public static String[] grantableFeatures = #[ name.grantableFeatures, birthdate.grantableFeatures, address.grantableFeatures ].flatten.toList
	val public static String[] definableFeatures = #[ name.group, birthdate.group, address.group ]
	
	def static getSpec(Message protoMessage) {
		protoMessage.class.spec
	}
	
	def static <T extends Message> getSpec(Class<T> featureClass) {
		#[ name, birthdate, address ].findFirst [ featureTypeMapping.values.contains(featureClass) ]
	}
	
	def static getSpec(String featureId) {
		if (featureId.nullOrEmpty) throw new IllegalArgumentException('Feature id has to be defined')
		
		val spec = #[ name, birthdate, address ].findFirst [ it.grantableFeatures.contains(featureId) ]
		if (spec === null) throw new IllegalArgumentException('''Unknown feature: «featureId»''')
		
		spec
	}
	
	def static <T extends Message> T parse(byte[] serialized, Class<T> protoClass) {
		switch protoClass {
			case Name: Name.parseFrom(serialized)
			case FirstName: FirstName.parseFrom(serialized)
			case LastName: LastName.parseFrom(serialized)
			case Initials: Initials.parseFrom(serialized)
			
			case Birthdate: Birthdate.parseFrom(serialized)
			case Birthyear: Birthyear.parseFrom(serialized)
			case Birthday: Birthday.parseFrom(serialized)
			
			case Address: Address.parseFrom(serialized)
			case City: City.parseFrom(serialized)
			case Country: Country.parseFrom(serialized)
		} as T
	}
	
	@Accessors(PUBLIC_GETTER)
	static class NameSpec implements Spec<Name> {
		val group = 'name'
		
		val firstName = feature('first_name')
		val lastName = feature('last_name')
		val initials = feature('initials')
		
		val featureComponents = #[ firstName, lastName ]
		val grantableFeatures = #[ group, firstName, lastName, initials ]
		
		val featureTypeMapping = #{
			group -> Name,
			firstName -> FirstName,
			lastName -> LastName,
			initials -> Initials			
		}
		
		override validate(Name message) {
			
		}
		
		override deriveFeatures(Name feature) {
			val firstName = FirstName.newBuilder.setFirstName(feature.firstName).build
			val lastName = LastName.newBuilder.setLastName(feature.lastName).build
			val initials = Initials.newBuilder.setInitials(getInitials(feature.firstName, feature.lastName)).build
			
			#[ firstName, lastName, initials ]
		}
		
		def static getInitials(String firstName, String lastName) {
			#[ firstName, lastName ]
				.map [ split(' ').toList ]
				.flatten
				.filter [ !nullOrEmpty ]
				.map [ charAt(0) ]
				.filter [ isUpperCase ]
				.join
		}
	}
	
	@Accessors(PUBLIC_GETTER)
	static class BirthdateSpec implements Spec<Birthdate> {
		val group = 'birthdate'
		
		val year = feature('year')
		val month = feature('month')
		val day = feature('day')
		val birthday = feature('birthday')
		
		val featureComponents = #[ year, month, day ]
		val grantableFeatures = #[ group, year, birthday ]
		
		val featureTypeMapping = #{
			group -> Birthdate,
			birthday -> Birthday,
			year -> Birthyear
		}
		
		override validate(Birthdate message) {
			
		}
		
		override deriveFeatures(Birthdate feature) {
			val birthyear = Birthyear.newBuilder.setYear(feature.year).build
			val birthday = Birthday.newBuilder.setMonth(feature.month).setDay(feature.day).build
			
			#[ birthyear, birthday ]
		}
	}
	
	@Accessors(PUBLIC_GETTER)
	static class AddressSpec implements Spec<Address> {
		val group = 'address'
		
		/** 2-character country code, ISO 3166-1 alpha-2 */
		val country = feature('country')
		val province = feature('province')
		val city = feature('city')
		val addressLine1 = feature('address_line_1')
		val addressLine2 = feature('address_line_2')
		val postalCode = feature('postal_code')
		
		val featureComponents = #[ country, province, city, addressLine1, addressLine2, postalCode ]
		val grantableFeatures = #[ group, country, city ]
		
		val featureTypeMapping = #{
			group -> Address,
			country -> Country,
			city -> City
		}
		
		override validate(Address message) {
			if (!message.country.empty && CountryCode.getByCode(message.country)?.alpha2 != message.country)
				throw new IllegalArgumentException('Country code must be ISO 3166-1 alpha-2 compliant (2 characters)')
		}
		
		override deriveFeatures(Address feature) {
			val city = City.newBuilder.setCity(feature.city).setProvince(feature.province).setCountry(feature.country).build
			val country = Country.newBuilder.setCountry(feature.country).build
			
			#[ city, country ]
		}
	}
}
