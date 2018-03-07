#!/usr/bin/env node

const neon = require('@cityofzion/neon-js')
const Neon = neon.default

async function main(argv) {
	neon.api.setApiSwitch(0)
	neon.api.setSwitchFreeze(true)

	const net = argv[2]
	const wif = argv[3]
	const balance = argv[4]
	const contractScriptHash = argv[5]
	const operation = argv[6]
	const args = argv.slice(7)

	await invoke(net, wif, balance, contractScriptHash, operation, args)
}

async function invoke(net, wif, balance, scriptHash, operation, args) {
	const account = Neon.create.account(wif)

	const contractArgs = []
	for (var i = 0; i < args.length; i+=2) {
		const type = args[i]
		const value = args[i+1]
		var param
		switch(type) {
			case '0x02': param = neon.sc.ContractParam.integer(value); break;
			case '0x05': param = neon.sc.ContractParam.byteArray(value); break;
			case '0x07': param = neon.sc.ContractParam.string(value); break;
			case '0x10': param = neon.sc.ContractParam.array(value); break;
			default: throw "Unsupported type " + type
		}
		contractArgs.push(param)
	}
	
	const invokeProperties = {
		scriptHash: scriptHash,
		operation: operation,
		args: contractArgs
	}

	const invokeScript = Neon.create.script(invokeProperties)

	const gasCost = 1
	const gasAssetId = Neon.CONST.ASSET_ID.GAS
	const intents = [
		{
			assetId: gasAssetId,
			value: 0.00000001, 
			scriptHash: Neon.get.scriptHashFromAddress(account.address)
		}
	]
	const config = {
		net: net,
		address: account.address,
		privateKey: account.privateKey,
		intents: intents,
		script: invokeScript,
		gas: gasCost
	}

	//if (balance != '{}') config.balance = JSON.parse(balance)

	try {
		const invocation = await neon.api.doInvoke(config)
		//console.log(JSON.stringify(invocation, null, 1))
		const txid = invocation.response.txid
		if (txid == null) throw "No transaction id received from invocation"
		else {
			console.log(JSON.stringify(invocation.balance))
			console.log(txid)
		}
	}
	catch (err) {
		console.error(err)
	}
}

if (require.main === module) {
    main(process.argv);
}
