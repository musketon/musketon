#!/usr/bin/env node

const neon = require('@cityofzion/neon-js')
const Neon = neon.default

function main(argv) {
	const key = argv[2]

	const account = Neon.create.account(key)

	var privateKey
	try { 
		privateKey = account.privateKey
	} catch(e) {
		// leave null
	}

	var publicKey
	var publicKeyUncompressed
	try { 
		publicKey = account.publicKey
		publicKeyUncompressed = account.getPublicKey(false)
	} catch(e) {
		// leave null
	}

	[ account.address, Neon.u.reverseHex(neon.wallet.getScriptHashFromAddress(account.address)), publicKey, publicKeyUncompressed, privateKey ].forEach(key => console.log(key))
}


if (require.main === module) {
    main(process.argv);
}
