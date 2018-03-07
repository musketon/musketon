package org.musketon.neo.annotations

interface OperationDocs {
	def String getName()
	
	def String[] getArgNames()
	def byte[] getArgTypes()
	
	def String getDocs()
}
