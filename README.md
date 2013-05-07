V-HAB / STEPS Bootstrapping Package
===================================
Downloaded from GITlab at http://steps.lrt.mw.tum.de

How to get started with git / GITlab
-----------------------------
For Windows: 

* If not already installed, download PuTTY at http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html
* Install PuTTY
* Download the SourceTree app at http://www.sourcetreeapp.com
* Install SourceTree
* In the first window enter your full, real name and your mytum e-mail address, then click next.
* In the second window select 'PuTTY/Plink (recommended)', then click next.
* The installer will ask you for your key file, just click 'cancel'.
* In the third window do nothing, just click 'Finish'.
* SourceTree should now open.
* In the top menu select 'Tools' -> 'Create or Import SSH Keys'. This will open the PuTTY Key Generator.
* Click 'Generate' and move the mouse around in the indicated area
* Once the key generation is completed, enter a passphrase and repeat it in the field below
* Click 'Save public key' and save the file in a new directory anywhere on your system using the appendix '.pub'
* Click 'Save private key' and save the file in the same directory as in the previous step, this time using the appendix '.ppk'
* In the top menu select 'Conversions' -> 'Export OpenSSH key' and save the file in the same directory as before without an appendix.
* Select the entire contents of the field 'Public key for pasting into OpenSSH authorized_keys file' and copy them to the clipboard. 
* Close the PuTTY Key Generator
* In the browser navigate to your profile page and select the tab 'SSH Keys'
* Click 'Add new' and paste the copied key into the field 'Key', give it a title and click 'save'.
* In the SourceTree top menu select 'Tools' -> 'Options' and in the 'General' tab set the SSH Client to 'OpenSSH' and click 'ok'.
* Click 'clone / new' and enter git@steps.lrt.mw.tum.de:bootstrapping.git in the field 'Source Path / URL'.
* Once you try to edit the field 'Destination Path', a window will pop up asking you, if you want to launch the SSH Agent. Say yes.
* Navigate to the folder you created earlier and select the file with the .ppk appendix.
* Then click 'Retry' in the next pop up window.
* The field 'Repository Type' should now say 'This is a Git repository'.
* Now select a destination path on your system where you want to store your files and press 'clone'.
* SourceTree will now download all neccessary files to your machine. 

TODO Insert the following steps needed to create the user folder and commit and push it to the server.

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