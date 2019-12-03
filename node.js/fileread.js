var fs = require('fs')
var path=require('path')

// var contents = fs.readFileSync ('./inputoutput.js', 'UTF-8');

fs.readdir ('.', function(err, files){
    files.forEach(function(filename){
        var outfile = path.join(__dirname, filename);
        var stats = fs.statSync (outfile);
        if (stats.isFile()) {
            console.log ('its a file         ' + outfile);
            fs.readFile(outfile, 'UTF-8', function(err,contents){
                console.log(contents);
            });
        } else {
            console.log('its a directory     ' + outfile);
            fs.readdir(outfile, function(err, files) {
                files.forEach(function(filename){
                    var file = path.join(outfile, filename);
                    var stats = fs.statSync (file);
                    if (stats.isFile()) {
                        console.log ('its a file         ' + file);
                    } else {
                        console.log('its a directory     ' + file);
                    }
                });
            });
         }
    })
});

// console.log(contents);