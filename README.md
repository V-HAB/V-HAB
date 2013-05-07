V-HAB / STEPS Bootstrapping Package
===================================
Downloaded from GITlab at http://steps.lrt.mw.tum.de

How to get started with git / GITlab
-----------------------------
For Windows:
* If not already installed, download PuTTY at http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html
* Install PuTTY
* Download the SourceTree app at http://www.sourcetreeapp.com
* Install, say yes or ok to everything and select PuTTY and not OpenSSH
* Open SourceTree
* In the top menu select 'Tools' -> 'Create or Import SSH Keys'. This will open the PuTTY Key Generator.
* Click 'Generate' and move the mouse around in the indicated area
* Once the key generation is completed, enter a passphrase
* Save the public key in a new directory anywhere on your system using the appendix '.pub'
* Save the private key in the same directory using the appendix '.ppk'
* In the top menu select 'Conversions' -> 'Export OpenSSH key' and save the key in the same directory as before without an appendix.
* Select the entire contents of the field 'Public key for pasting into OpenSSH authorized_keys file' and copy them to the clipboard. 
* Close the PuTTY Key Generator
* In the browser navigate to your profile page and select the tab 'SSH Keys'
* Click 'Add new' and paste the copied key into the field 'Key', give it a title and click 'save'.
* In the SourceTree top menu select 'Tools' -> 'Options' and in the 'General' tab set the SSH Client to 'OpenSSH' and click 'ok'.
* Click 'clone / new' and enter git@steps.lrt.mw.tum.de:bootstrapping.git , then click 'clone'.
* SourceTree will ask for your SSH key, select the file without the appendix that you created earlier
* Go to the local directory in Matlab, execute *init.m* and then your main script (main.m executes one of the tutorials).

For Mac: help yourself ...


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

About Matlab OOP
----------------
More about Matlab packages / class organization:
* http://www.mathworks.de/de/help/matlab/matlab_oop/scoping-classes-with-packages.html
* http://www.mathworks.de/de/help/matlab/matlab_oop/saving-class-files.html
More about Matlab classes:
* http://www.mathworks.de/de/help/matlab/ref/classdef.html
* http://www.mathworks.de/de/help/matlab/object-oriented-programming-in-matlab.html