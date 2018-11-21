User directory
==============

All functionalities and simulations by users go here. Classes and functions have to be created in the according project directory within the users own directory.

If user 'some_user' creates a project 'my_project' in GITlab, the according directory in here would be '+some_user/+my_project'. Only classes and functions can be put in there.

To execute the simulation, go to the main bootstrapping directory, make a copy of the main.m, rename it to e.g. main_some_user_my_project.m and update it to use your classes, e.g. some_user.some_project.NewSystem(...).

Coding Guidelines and Conventions
==============

Prefixes for variables - naming conventions
i = integer
f = float
r = ratio (0..1)
s = string
b = bool
a = array
m = matrix
c = cell
t = struct
o = object
h = handle (file, graphics, function, ...)
p = map

Awesome when mixed, e.g. taiSomething would be a struct, with each field holding an array of integers. For a struct with non-uniform values, the key should contain the prefix, e.g. tSomething and then tSomething.fVal, tSomething.sName (the tSomething could also be named txSomething - more clear). Struct-hierarchy e.g. ttxMatter - each field of main struct contains another struct (or several?), with mixed values (the x specifically says mixed values, could be omitted since in this example (from @matter.table), the values are containing the prefix, e.g. fMolarMass).
