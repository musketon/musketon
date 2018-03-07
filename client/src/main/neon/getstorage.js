#!/usr/bin/env node

const neon = require('@cityofzion/neon-js')
const Neon = neon.default

async function main(argv) {
	const net = argv[2]
	const scriptHash = argv[3]
	const key = argv[4]
	
	getstorage(net, scriptHash, key)
}

async function getstorage(net, scriptHash, key) {
	try {
		const url = await neon.api.neoscan.getRPCEndpoint(net)
		const response = await neon.rpc.Query.getStorage(scriptHash, key).execute(url)
		console.log(response.result)
	} catch(e) {
		console.error(e)
	}
}

if (require.main === module) {
    main(process.argv);
}
