const fs = require('fs');
const contractJson = JSON.parse(fs.readFileSync('./build/contracts/GCoin.json', 'utf8'));
const abi = contractJson.abi;
console.log(JSON.stringify(abi));
