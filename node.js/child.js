var exec = require('child_process').exec;
var util = require('util')
// exec('open wwww.linkedin.com')     open in browser
// exec('open -a Terminal .')

var dir = '~/OneDrive/DBAStuff/SCRIPTS/000AJREPO'

exec('ls ${dir}', function(err, stdout) {
    if (err) {
        throw err;
    }
    util.log('listing finished');
    console.log (stdout)
});

