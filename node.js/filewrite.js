var fs = require (fs);

var md = `
samoke file
blah blah
`;

fs.writeFile ('test.md', md.trim(), function(err){

    console.log('file create');

});