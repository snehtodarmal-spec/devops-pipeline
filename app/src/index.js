// BUG: Using an undefined variable
console.log(myUndefinedVariable);

// SECURITY RISK: Using eval is dangerous
eval("console.log('This is a security risk')");

// CODE SMELL: Empty block
if (true) {
}