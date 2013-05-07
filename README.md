V-HAB / STEPS Bootstrapping Package
===================================
Downloaded from GITlab at http://steps.lrt.mw.tum.de

Basic repository with the framework for V-HAB / STEPS. Contains three directories:
* core: central, shared V-HAB framework.
* lib: helper functions, pre/post processing, logging, GUI, date functions, ...
* user: user-specific simulations

The core and lib packages are managed, i.e. most likely no changes should be done or can be commited to the online repository. Help can be found in class comments (HOW to use the class) and in the wiki of the according repository / project on GITlab.

To create a new simulation project:
* go to GITlab and create a new project (assuming your username is *bob* and your project is *alice*).
* create a new directory locally inside the bootstrapping package: */user/bob/alice* (i.e. *{root}/user/{username}/{project}*)
* ONLY package directories, classes and functions can be included ONLY in a project directory, i.e. only in */user/bob/alice*.
* Copy the 'main.m' file in the bootstrapping root dir to e.g. main_alice.m, edit, execute. Has to reside within the bootstrapping directory. Your classes can be accessed with e.g. bob.alice.myClass().
* Use SourceTreeApp or the GIT console to initialize a GIT directory within */user/bob/alice*. Add the remote repository (steps.lrt.mw.tum.de:bob/alice.git). Commit & push.


Get started with git / GITlab
-----------------------------
For Windows:
* Download http://www.sourcetreeapp.com & PuTTY (http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html)
* Install, select 'putty' and not OpenSSH
* Select menu -> 'Create or Import SSH Key' -> create new RSA2 key. Add to your user profile in GITlab.
* Click 'clone / new' and enter *git@steps.lrt.mw.tum.de:bootstrapping.git*, then click 'clone'.
* Go to the local directory in Matlab, execute *init.m* and then your main script (main.m executes one of the tutorials).

For Mac: help yourself ... Pimmel


About Matlab OOP
----------------
More about Matlab packages / class organization:
* http://www.mathworks.de/de/help/matlab/matlab_oop/scoping-classes-with-packages.html
* http://www.mathworks.de/de/help/matlab/matlab_oop/saving-class-files.html
More about Matlab classes:
* http://www.mathworks.de/de/help/matlab/ref/classdef.html
* http://www.mathworks.de/de/help/matlab/object-oriented-programming-in-matlab.html