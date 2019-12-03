console.log(process.argv) // gives all command line aruguments in an array
                          // including the executable node as [0]
console.log(process.argv[1])

function grab(flag) {
    var index = process.argv.indexOf(flag);   // output -1 if not found.
    return ( index === -1 ) ? null : process.argv[index+1]
}

var blah = grab('--blah');
var myeh = grab('--myeh');

if ( !blah || !myeh ) {
    console.log ('no dice?')
} else {
    console.log ('you are a cutie pie')
}

