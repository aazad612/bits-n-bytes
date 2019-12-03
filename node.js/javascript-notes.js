Brave Browser

// in console
    document.body.innerHTML= "<h1> date" + date + "</h1>"

// Date
    var date = new Date()
    date.getMonth()
    date.getDate()
    date.getFullYear()

// variables
    var a = 5;
    var b = 4;
    var sum = a + b;
    console.log(Typeof sum);
    const MYCONSTRANT = 5;
    let 

    // arrays
        var pens = [ "Red", "Blue", "yellow" ];
        >
        pens = new Array [ "Red", "Blue", "yellow" ];
        
        var firstPen = pens[0];
        pens[0] = "purple";

        // methods
            pens.reverse();
            pens.length;
            pens.shift; //remove first value
            pens.unshift("green"); // add to the beginning of the line. 
            pens.pop;
            pens.push("green");
            splice / slice / indexOf / join(" | ")

// camelCase:
    // variables => start with lower case
    // objects and classes: start with uppercase
    // constants: ALL CAPS
    // comments: 
        single line =: //
        multiline  =: /* */

// Math:
    a += 1;
    a++;    // display first then add
    ++a;    // add and then display result
    a=4, n=4
    // NaN = variable in math equation is a string. 

// if:
    if ( a == b) {
        numbersMatch = true;
    } else {
        numbersMatch = false;
    }

    a == b ? console.log("Match") : console.log("No Match")

    if ( a == b && c <= d && a=== c || !a ) {}

========================================================================
// functions 

function findbigger(){
    a > b ? console.log("boom boom") : console.log("boom boom boom");
}

var a = 10;
var b = 15;

findbigger();

----------------------------------------------------------------------

function findbigger (a , b ){
    a > b ? console.log("boom boom") : console.log("boom boom boom");
}

var avalue = 10;
var bvalue = 15;

findbigger(avalue, bvalue);

----------------------------------------------------------------------

function findbigger (a , b ){
    var c = a + b;
    return c; 
}

var avalue = 10;
var bvalue = 15;

results = findbigger(avalue, bvalue);

----------------------------------------------------------------------

var avalue = 10;
var bvalue = 15;

results = function(avalue, bvalue) {
    var c = avalue + bvalue;
    return c; 
};

results();

----------------------------------------------------------------------

results = (function(avalue, bvalue) {
    var c = avalue + bvalue;
    return c; 
})(9,10);

----------------------------------------------------------------------

results = (function(avalue, bvalue) {
    var c = avalue + bvalue;
    let localvar = 2;
    if (localvar) {
        let localvar = "what the hell"  // scope of this localvar is 
                                        // just the if statement. 
    return c; 
    }
})(9,10);

----------------------------------------------------------------------

var course = new Object();

course.instructor = "AJ";
course.student = "Mike";

-----------------------------------

var course = {
    instructor = "AJ",
    student = "Mike", 
    views = 0
    updateViews: function(){
        return ++course.views;
    }
}

course.updateViews;

-----------------------------------

function Course(instructor, student, views){
    this.title = title;
    this.instructor = instructor;
    this.views = views
    this.updateViews = function(){
        return ++this.views;
    }
}

var Course2 = new Course ("Ron", "Johney", 0);

-----------------------------------

var coursees = [
    new Course ("Ron", "Johney", 0);
    new Course ("Chuck", "Ron", 0);
];

var instructor = courses[1].instructor;

courses[1].updateViews();

-----------------------------------

course.instructor = course ["instrctor"]    // to handle non-std values can be 
                                            // expected. 

-----------------------------------
// CLOSURE

function doSomeMath() {
    var a =5;
    var b =5;

    function multiply(){
        var results = a*b;
        return result;
    }
    return multiply;
}

var theResult = doSomeMath();   // here the function retains the values of 
                                // outside variable values out of the scope 
                                // of the doSomeMath function. 



======================================================================
// DOM - Documents object model. 

document.querySelector(".masthead")       
document.querySelectorAll("a")

document.querySelector(".menu .has-children a")       
document.querySelectorAll(".social-nav a[href*='linkedin.com']")

for forms: 
    document.getElementByID("ID");
    document.getElementByClassName("classname");
    document.getElementByTagName("HTML tag");

document.body
document.title
document.URL 

mozilla develiper network. 

MDN Element

----------------------------------------------------------------------

// Events

.