// node.js

var hello = 'whats up dude'      // this is not part of the global namespace.
                                 // in the browser its in global namespace

var justnode = hello.slice(5)
----------------------------------------

var path = require("path")      //import modules

console.log(path.basename(__filename))
console.log(__dirname)
console.log(__filename)

// implicitly adds the "/"

util.log(webpath)   // adds a timestamp

----------------------------------------

console.log(process.argv) // gives all command line aruguments in an array
                          // including the executable node as [0]
console.log(saying.trim());
data.toString().trim();
----------------------------------------

http://www.davidmclifton.com/2011/07/21/javascript-objects-and-inheritance/

module.exports


