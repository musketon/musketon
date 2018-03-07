#!/usr/bin/env node

const neon = require('@cityofzion/neon-js')
const Neon = neon.default

async function main(argv) {
	const net = argv[2]
	const txid = argv[3]

	await getConfirmations(net, txid)
}

async function getConfirmations(net, txid) {
	try {
		const url = await neon.api.neoscan.getRPCEndpoint(net)
		const response = await neon.rpc.Query.getRawTransaction(txid).execute(url)
		//console.log(JSON.stringify(response, null, 1))
		console.log(response.result.confirmations)
	}
	catch (err) {
		console.error(err)
	}
}

if (require.main === module) {
    main(process.argv);
}
