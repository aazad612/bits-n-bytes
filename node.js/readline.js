// READLINE
var readline = require('readline');
var rl = readline.createInterface({input: process.stdin, output: process.stdout});

var realPerson = {
    name: '',
    sayings: []
}

rl.question('who are you    ', function(answer){
    // got the name of the person
    realPerson.name = answer;
    // Net question
    rl.setPrompt ('what would you say! ')
    rl.prompt();
    //interate getting answers
    rl.on('line', function(saying) {
        if (saying.toLowerCase().trim() === 'exit'){
             rl.close();
         } else {
             realPerson.sayings.push(saying.trim());
         }
    })
});

rl.on ('close', function(){
    console.log ( '%s says %j', realPerson.name, realPerson.sayings)
    process.exit();
})
