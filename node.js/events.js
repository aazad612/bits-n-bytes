// var events=require('events');
// var EventEmitter = new events.EventEmitter;
// http://www.davidmclifton.com/2011/07/21/javascript-objects-and-inheritance/
/*
var emitter = new events.EventEmitter();
var EventEmitter = require('events').EventEmitter;
emitter.on ('customEvent', function(message, status){
    util.log(' I am executing the custom fucntion!!! ')
})
emitter.emit ('customEvent', 'your mom', 200);
*/


var util=require('util');

var EventEmitter = require('events').EventEmitter;  // consructor module

var Person = function(name){
    this.name = name;
}

util.inherits(Person, EventEmitter);

var ben = new Person ('Zinga Bombil');

ben.on('speak', function(said) {
    util.log (this.name + ' said ' + said);
})

ben.emit ('speak','what the heck');

