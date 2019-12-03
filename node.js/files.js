var fs = require('fs')

// synchronous
//var files = fs.readdirSync('.')

// asynchronous
fs.readdir('.', function (err, filelist){
    if (err) {
        throw err;
    }
    console.log(filelist);
});

console.log(" Reading file....." );
