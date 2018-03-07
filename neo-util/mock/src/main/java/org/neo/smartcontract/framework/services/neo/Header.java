package org.neo.smartcontract.framework.services.neo;

import java.util.Date;

public class Header {//implements ScriptContainer {
	public native byte[] hash();

	public native int version();

	public native byte[] prevHash();

	public native byte[] merkleRoot();

	public int timestamp() {
		return (int) (new Date().getTime() / 1000);
	}

	public native long consensusData();

	public native byte[] nextConsensus();
}
