var path = require("path")      //import modules

console.log(path.basename(__filename))

var hello = 'whats dude';     // this is not part of the global namespace.
                                 // in the browser its in global namespace

var justNode = hello.slice(5);

console.log(`Not sure I get it ${justNode}`);  // to add to another string
console.log("Not sure I get it" + justNode );  // to add to another string

console.log(__dirname)
console.log(__filename)

