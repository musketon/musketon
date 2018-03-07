package org.neo.smartcontract.framework.services.neo;

public class Blockchain {
	public static int height() {
		return 0;
	}

	public static Header getHeader(int height) {
		return new Header();
	}

	public static Header getHeader(byte[] hash) {
		return new Header();
	}

//	public native static Block getBlock(int height);
//
//	public native static Block getBlock(byte[] hash);
//
//	public native static Transaction getTransaction(byte[] hash);
//
//	public native static Account getAccount(byte[] script_hash);
//
//	public native static byte[][] getValidators();
//
//	public native static Asset getAsset(byte[] asset_id);

	public native static Contract getContract(byte[] script_hash);
}
