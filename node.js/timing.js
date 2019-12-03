var waitTime = 3000;            // onetime
var currentTime = 0;
var waitInterval = 500;         // repeat execution
var percentWaited = 0;
const readline = require('readline');

var r1 = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

//readline.cursorTo(process.stdout, 0, 0)
//readline.clearScreenDown(process.stdout);

function showStatusOnSameLine(percent){
    readline.clearLine(process.stdout,0);
    readline.cursorTo(process.stdout,0);
    r1.write(`processing the first beep ${percent} `);
}

var interval = setInterval(function () {
    currentTime += waitInterval;
    percentWaited = Math.floor((currentTime/waitTime) * 100);
    showStatusOnSameLine(percentWaited);
}, waitInterval);

// this code would execute whatever is part of the timeout function
// after the timeout is over. In the meantime any other function can execute.

setTimeout(function () {
    // clearInterval(interval);
    showStatusOnSameLine(100)
    console.log ('done');
    process.exit();
}, waitTime);
// process.stdout.write('\n');
// showStatusOnSameLine(percentWaited);

