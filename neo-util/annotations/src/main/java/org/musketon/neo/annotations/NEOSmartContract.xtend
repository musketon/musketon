package org.musketon.neo.annotations

import java.lang.annotation.Target
import java.math.BigInteger
import org.eclipse.xtend.lib.macro.AbstractClassProcessor
import org.eclipse.xtend.lib.macro.Active
import org.eclipse.xtend.lib.macro.RegisterGlobalsContext
import org.eclipse.xtend.lib.macro.TransformationContext
import org.eclipse.xtend.lib.macro.declaration.ClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.MethodDeclaration
import org.eclipse.xtend.lib.macro.declaration.MutableClassDeclaration
import org.eclipse.xtend.lib.macro.declaration.TypeDeclaration
import org.eclipse.xtend.lib.macro.declaration.TypeReference
import org.eclipse.xtend.lib.macro.declaration.Visibility
import org.eclipse.xtend2.lib.StringConcatenationClient

import static extension java.lang.Character.*
import org.neo.smartcontract.framework.Helper

/**
 * This active annotation generates:
 * <li> the method {@code execute} on the annotated class that does the cumbersome invocation arg parsing 
 * for every method annotated with {@code @Operation}. The operations can be invoked by their standard java
 * lower camelcase name or by their upper camelcase name. On methods declared by inner classes, the operation
 * name will be prefixed with the declaring inner class: "InnerClass.Method" instead of just "Method".
 * <li> a new class, containing the documentation of the declared operations.
 */
@Active(NEOSmartContract.Processor)
annotation NEOSmartContract {
	@Target(METHOD)
	annotation Operation {
		
	}
	
	class Processor extends AbstractClassProcessor {
		extension TransformationContext context
		extension RegisterGlobalsContext registerGlobalsContext
		
		def Iterable<MethodDeclaration> getContractOperations(ClassDeclaration cls) {
			cls.declaredClasses.map [ contractOperations ].flatten + 
			cls.declaredMethods.filter [ 
				findAnnotation(NEOSmartContract.Operation.newTypeReference.type) !== null
			]
		}
		
		override doRegisterGlobals(ClassDeclaration cls, extension RegisterGlobalsContext context) {
			this.registerGlobalsContext = context
		}
		
		def static String operationsClassName(TypeDeclaration cls) {
			'''«cls.qualifiedName»Docs'''
		}
		
		def static operationClassName(ClassDeclaration cls, String operationsClassName, MethodDeclaration operationMethod) {
			val operationsClass = operationsClassName.split('\\.').toList
			val operationPath = operationMethod.declaringType.qualifiedName.split('\\.').drop(operationsClass.size)
			val operationClass = operationMethod.simpleName.toFirstUpper
			
			#[ operationsClass, operationPath, #[ operationClass ] ].flatten.join('.')
		}
		
		def registerOperationsClass(String operationClassName) {
			val components = operationClassName.split('\\.')
			
			components.indexed.filter [ value.charAt(0).isUpperCase ].forEach [
				val className = components.take(key + 2).join('.')
				if (findClass(className) === null)
					registerClass(className)
			]
		}
		
		override doTransform(MutableClassDeclaration cls, extension TransformationContext context) {
			this.context = context
			
			val operations = cls.contractOperations
			
			operations.forEach [
				if (!static) 
					cls.addError('''Method «simpleName» has to be static''')
				if (operations.filter [ otherOperation | simpleName == otherOperation.simpleName ].size > 1)
					cls.addError('''Found multiple operations with method name «simpleName»''')
			]
//			
			val operationsClassName = cls.operationsClassName
			registerClass(operationsClassName)
			
			val operationClassNames = cls.contractOperations.map [ it -> cls.operationClassName(operationsClassName, it) ]
			operationClassNames.forEach [
				registerOperationsClass(value)
			]
			val operationClasses = operationClassNames.map [ key -> findClass(value) ]
			
			val mainReturnType = cls.declaredMethods.findFirst [ simpleName == 'Main' ]?.returnType
			if (mainReturnType === null) {
				cls.addError('Could not find Main method')
				return
			}
			
			val mismatchedOperations = operations.filter [ returnType != mainReturnType ]
			if (!mismatchedOperations.empty) {
				cls.addError('''The following methods should return the Main's return type «mainReturnType» or should not be public: «mismatchedOperations.map [ simpleName ].join(', ')»''')
				return
			}
			
			cls.addMethod('execute') [
				static = true
				
				val paramOperation = 'operation'
				val paramArgs = 'args'
				
				addParameter(paramOperation, string)
				addParameter(paramArgs, byteArray.newArrayTypeReference)
				varArgs = true
				
				returnType = mainReturnType
				
				body = '''
					«FOR operationMethod : operations SEPARATOR ' else '»
					if («cls.getOperationNamePossibilities(operationMethod).map ['''«paramOperation» == "«it»"'''].join(' || ')») {
						«FOR declaredArg : operationMethod.parametersNonVarArg.indexed»
							«declaredArg.value.type» _«declaredArg.value.simpleName» = «convert(byteArray, declaredArg.value.type, '''«paramArgs»[«declaredArg.key»]''')»;
						«ENDFOR»
						«IF operationMethod.isVarArgs»
							
						«ENDIF»
						«invokeAndReturn(operationMethod, returnType)»
					}«ENDFOR»
					return null;
				'''
			]
			
			operationClasses.forEach [
				val operationMethod = key
				val operationClass = value
				
				operationClass => [
					implementedInterfaces = #[ OperationDocs.newTypeReference ]
					declaringType.addField(simpleName) [
						primarySourceElement = operationMethod
						type = operationClass.newTypeReference
						visibility = Visibility.PUBLIC
						static = true
						final = true
						initializer = '''new «operationClass»()'''
					]
					addMethod('getName') [
						returnType = string
						body = '''return "«operationClass.qualifiedName.split('\\.').filter [ charAt(0).isUpperCase ].drop(1).join('.')»";'''
					]
					addMethod('getArgNames') [
						returnType = string.newArrayTypeReference
						body = '''return new String[] {«operationMethod.parameters.map ['''"«simpleName»"'''].join(', ')»};'''
					]
					addMethod('getArgTypes') [
						returnType = byteArray
						body = listTypes(operationMethod.parameters.map [ type.toNeoTypeDeclaration ])
					]
					val docComment = operationMethod.docComment ?: ''
					val docSplit = docComment.split('@return')
					val mainDoc = docSplit.head.trim.replace('\n', ' ')
					addMethod('getDocs') [
						returnType = string
						body = '''return "«mainDoc»";'''
					]
					if (mainReturnType == primitiveByte.nestedArray) {
						val docReturnFields = docSplit.last.trim.split(', ').filter [ !nullOrEmpty ].map [ split(' ') ].map [ head -> last ]
						if (docReturnFields.empty) {
							cls.addError('''Method «operationMethod.simpleName» has no declared return types in the java doc''')
							return
						}
						addMethod('getReturnNames') [
							returnType = string.newArrayTypeReference
							body = '''return new String[] {«docReturnFields.map ['''"«value»"'''].join(', ')»};'''						
						]
						addMethod('getReturnTypes') [
							returnType = byteArray
							val types = docReturnFields.map [ key -> key.toNeoTypeDeclaration ]
							val notFoundTypes = types.filter [ value === null ].map [ key ]
							if (!notFoundTypes.empty) {
								cls.addError('''Could not find NEO equivalent for declared types on «operationMethod.simpleName» method: «notFoundTypes.join(', ')»''')
								return
							}
							body = listTypes(types.map [ value ])
						]
					}
				]
			]
		}
		
		def Iterable<String> getOperationNamePossibilities(ClassDeclaration cls, MethodDeclaration method) {
			if (method.declaringType == cls) #[ method.simpleName, method.simpleName.toFirstUpper ]
			else #[ 
				'''«method.declaringType.qualifiedName.substring(cls.qualifiedName.length + 1)».«method.simpleName»''',
				'''«method.declaringType.qualifiedName.substring(cls.qualifiedName.length + 1)».«method.simpleName.toFirstUpper»'''
			]
		}
		
		def getParametersNonVarArg(MethodDeclaration method) {
			if (method.isVarArgs) method.parameters.take(method.parameters.size - 1)
			else method.parameters
		}
		
		def StringConcatenationClient convert(TypeReference from, TypeReference to, StringConcatenationClient value) {
			if (from == to) {
				value
			} else if (to == string && from == byteArray) {
				'''«Helper».asString(«value»)'''
			} else if (to == byteArray && from == string) {
				'''«Helper».asByteArray(«value»)'''
			} else if (to == bigInteger && from == byteArray) {
				'''«Helper».asBigInteger(«value»)'''
			} else if (to == byteArray && from == bigInteger) {
				'''«Helper».asByteArray(«value»)'''
			} else value
		}
		
		def StringConcatenationClient invokeAndReturn(MethodDeclaration method, TypeReference resultType) {
			'''
				«IF !method.returnType.isVoid»«method.returnType» result = «ENDIF»«method.declaringType».«method.simpleName»(«method.parametersNonVarArg.map ['''_«simpleName»'''].join(', ')»);
				return«IF !method.returnType.isVoid» «convert(method.returnType, resultType, '''result''')»«ENDIF»;
			'''
		}
		
		def TypeReference byteArray() {
			primitiveByte.newArrayTypeReference
		}
		
		def TypeReference bigInteger() {
			BigInteger.newTypeReference
		}
		
		def TypeReference nestedArray(TypeReference type) {
			type.newArrayTypeReference.newArrayTypeReference
		}
		
		def StringConcatenationClient listTypes(String... neoParams) {
			'''
				byte[] bytes;
				«IF neoParams.empty»
					bytes = new byte[0];
				«ENDIF»
				«FOR parameter : neoParams.indexed»
					byte[] t«parameter.key» = «Helper».asByteArray(«BigInteger».valueOf(«parameter.value»));
					«IF parameter.key == 0»
						bytes = t«parameter.key»;
					«ELSE»
						bytes = «Helper».concat(bytes, t«parameter.key»);
					«ENDIF»
				«ENDFOR»
				return bytes;
			'''
		}
		
		/**
		 * Signature = 0x00,
		 * Boolean = 0x01,
		 * Integer = 0x02,
		 * Hash160 = 0x03,
		 * Hash256 = 0x04,
		 * ByteArray = 0x05,
		 * PublicKey = 0x06,
		 * String = 0x07,
		 * Array = 0x10,
		 * InteropInterface = 0xf0,   
		 * Void = 0xff
		 */
		def toNeoTypeDeclaration(Object type) {
			switch type {
				case 'Boolean', 
				case primitiveBoolean, 
				case Boolean.newTypeReference: 
					'0x01'
				
				case 'Integer', 
				case primitiveInt, 
				case Integer.newTypeReference: 
					'0x02'
				
				case 'ByteArray', 
				case 'BigInteger', 
				case byteArray, 
				case Byte.newTypeReference.newArrayTypeReference, 
				case bigInteger:
					'0x05'
				
				case 'String', 
				case string: 
					'0x07'
				
				case 'Array', 
				case primitiveByte.nestedArray, 
				case string.nestedArray, 
				case primitiveInt.nestedArray: 
					'0x10'
				
				case 'Void', 
				case primitiveVoid, 
				case Void.newTypeReference: 
					'0xff'
				
				default: 
					null
			}
		}
	}
}
