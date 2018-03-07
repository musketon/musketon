package org.neo.smartcontract.framework.services.neo;

public class Contract {
	public native byte[] script();

	public native StorageContext storageContext();

	public native static Contract create(byte[] script, byte[] parameter_list, byte return_type, boolean need_storage,
			String name, String version, String author, String email, String description);

	public native static Contract migrate(byte[] script, byte[] parameter_list, byte return_type, boolean need_storage,
			String name, String version, String author, String email, String description);

	public native static void destroy();
}
