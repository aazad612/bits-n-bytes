var path = require('path')

var webpath  = path.join (__dirname, 'www', 'files', 'uploads');
console.log (webpath)

var util = require('util')

util.log(webpath)   // adds a timestamp

// V8
var v8 = require ('v8')   // node.js is built on top of chromes v8 processor
util.log(v8.getHeapStatistics());


