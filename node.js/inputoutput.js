// process.stdout.write ( ' Std Out ')
// process.stdout.write ( ' I wanted a new line Std in  ')

process.stdout.write ('what is your name  > ');

var answer = [];

function ask(i) {
    process.stdin.on('data', function(data){
        process.stdout.write ('what is your name  > ');
        if (i == 0) {
            global.answer = [];
        }
        if (i == 3) {
            process.exit();
        }
        answer[i] = data.toString().trim();
        answer.push(answer[i]);
        i++;
        console.log( answer[i] + '   is learning node.js');
    });
}

process.on('exit', function(){
    process.stdout.write ('answers are = '+ answer);
})
ask(0);

//console.log( answer + 'buttercup is learning node.js')
