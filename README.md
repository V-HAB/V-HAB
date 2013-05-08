V-HAB / STEPS Bootstrapping Package
===================================

Downloaded from GITlab at <http://steps.lrt.mw.tum.de/>


How to get started with git / GITlab
------------------------------------

The following steps are only required the first time you setup your development environment. 

### Windows ###

* If not already installed, download PuTTY at <http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html>. 
* Install PuTTY (i.e. put the putty.exe in a place where you can find it again). 
* Download the SourceTree app at <http://www.sourcetreeapp.com/>. 
* Install SourceTree. 
* In the first window enter your full name, real name and the e-mail address of your account (e. g. `yourname@mytum.de`) here at the STEPS GITlab, then click next.
* In the second window select *PuTTY/Plink (recommended)*, then click next.
* The installer will ask you for your key file, just click *cancel*.
* In the third window do nothing, just click *Finish*.
* SourceTree should now open.
* In the top menu select *Tools* → *Create or Import SSH Keys*. This will open the PuTTY Key Generator.
* Click *Generate* and move the mouse around in the indicated area
* Once the key generation is completed, **enter a passphrase** (the password entered here has to be used again when adding the key to the available list of keys) and repeat it in the field below
* Click *Save public key* and save the file in a new directory anywhere on your system using the appendix `.pub`. 
* Click *Save private key* and save the file in the same directory as in the previous step, this time using the appendix `.ppk`. 
* In the top menu select *Conversions* → *Export OpenSSH key* and save the file in the same directory as before without an appendix.
* Select the entire contents of the field *Public key for pasting into OpenSSH authorized_keys file* and copy them to the clipboard. 
* Close the PuTTY Key Generator. 
* In the browser navigate to your profile page at <http://steps.lrt.mw.tum.de/> and select the tab *SSH Keys*. 
* Click *Add new* and paste the copied key into the field *Key*, give it a title and click *save*.
* In the SourceTree top menu select *Tools* → *Options* and in the *General* tab set the SSH Client to *OpenSSH* and click *ok*.
* Click *clone / new* and enter `git@steps.lrt.mw.tum.de:bootstrapping.git` in the field *Source Path / URL*.
* Once you try to edit the field *Destination Path*, a window will pop up asking you, if you want to launch the SSH Agent. Say yes.
* Navigate to the folder you created earlier and select the file with the `.ppk` appendix (you probably have to enter the password you used when creating the key).
* Then click *Retry* in the next pop up window.
* The field *Repository Type* should now say *This is a Git repository*.
* Now select a destination path on your system where you want to store your files and press *clone*.
* SourceTree will now download all neccessary files to your machine. 

See next section on how to use the bootstrapping repository, e.g. how to download the tutorial.

### Mac ###

See the [Mac Setup Wiki Page](http://steps.lrt.mw.tum.de/bootstrapping/wikis/setup-instructions-mac) for a step-by-step guide with screenshots. 

1. Download the SourceTree app at <http://www.sourcetreeapp.com/>. 
2. If the downloaded disk image was not automatically opened, (double) click the downloaded file. A Finder window should appear with both the *SourceTree* app and (pointing with a big arrow to) the *Applications* folder. 
3. To install SourceTree drag the *SourceTree* app and drop it onto the *Applications* folder. (You can then unmount the disk image and remove the downloaded file.) 
4. To setup the SSH keys (required for pushing changes from your local repository to the [STEPS server](http://steps.lrt.mw.tum.de)), open *Terminal* (either open Spotlight search and enter `Terminal` or launch Terminal from *Applications* → *Utilites*). 
5. In the Terminal command prompt, enter `ssh-keygen -C 'email@address.com'` (where `email@address.com` is **your STEPS GITlab email address**). Press `Enter` to start the command. 
6. The SSH key generator will ask for a file name, just press `Enter` to use the default file name. 
7. You will then be asked for a passphrase that you can assign freely to protect your SSH key file (please use a **strong password**!). This password may be asked for when pushing commits to the STEPS server (however you can save the password in your Mac OS keychain). Please remember that this password cannot be recovered (if you forget the password, you will need to create a new keyfile and update your STEPS GITlab profile, see below)! Press `Enter` after typing in the password (while you type, you will neither see the password nor any indication that you are actually entering anything; this is intentional albeit confusing at first). 
8. You will be asked to retype your chosen passphrase. Press `Enter`. Finally a random art image will be displayed. 
9. Then you have to add the public key to your STEPS GITlab account. First, enter `pbcopy << ~/.ssh/id_rsa.pub` and confirm with `Enter`, this will copy your public key to your clipboard (there will be no confirmation message in the Terminal). 
10. In the browser, navigate to your profile page at <http://steps.lrt.mw.tum.de/> and select the tab *SSH Keys*. 
11. Click *Add new* and paste (`CMD + V`) the copied key into the field *Key* (a cryptic text beginning with `ssh-rsa` and ending with your STEPS GITlab email address should appear; if not, repeat *step 9*), the title should then automatically be your STEPS GITlab email address. Click *save*. (You can quit the Terminal after successfully completing this step.) 
12. Launch *SourceTree* from the *Applications* folder. 
13. In the *Welcome* window, enter your full name and your STEPS GITlab email address (e.g. `username@mytum.de`). Make sure that both checkboxes are ticked, then click *Next*. 
14. Skip the *Connect to online services* and *Find local repositories* form by clicking *Next* and *Finish*. 
15. You can now create or clone repositories. Continue with *Clone a repository (Mac)* below. 

### Clone a repository (Mac) ###

Coming soon …


Bootstrapping Repository
------------------------

Basic repository with the framework for V-HAB / STEPS. Contains three directories:

* core: central, shared V-HAB framework.
* lib: helper functions, pre/post processing, logging, GUI, date functions, … (TBD)
* user: user-specific simulations

The core and lib packages are managed, i.e. most likely no changes should be done or can be commited to the online repository. Wiki of the according projects will soon contain some help.

### To get a tutorial: ###

* Example: `git@steps.lrt.mw.tum.de:tutorials/flow.git`
* Create a directory called `+tutorial` in the `user` directory. Create a sub-directory called `+flow` (see the GIT repository path)
* Click *Clone / New* in SourceTree, paste the address above, and select the newly created directory as the destination path
* Create a main script in the bootstrapping root directory called `main_tutorial_flow.m`, or copy and rename the template from `user/+tutorial/+flow/+main_tutorial_flow.m.example` to the root directory.


### To create a new simulation project: ###

* go to GITlab and create a new project (assuming your username is `bob` and your project is `spacestation`).
* create a new directory locally inside the bootstrapping package: `user/bob/spacestation` (i.e. `{steps}/user/{username}/{project}`)
* ONLY package directories, classes and functions can be included ONLY in a project directory, i.e. only in `/user/bob/spacestation`.
* Copy the `main.m` file in the bootstrapping root dir to e.g. `main_bob_spacestation.m`, edit, execute. Has to reside within the bootstrapping directory. Your classes can be accessed with e.g. `bob.spacestation.myClass()`. Please note that your main file is intentionally not inside the repository, and will thusly not be backuped by the version control system. 
* Use SourceTreeApp or the GIT console to initialize a GIT directory within `/user/bob/spacestation`. Add the remote repository (`steps.lrt.mw.tum.de:bob/spacestation.git`). Commit & push.


About Matlab OOP
----------------

More about Matlab packages / class organization:

* <http://www.mathworks.de/de/help/matlab/matlab_oop/scoping-classes-with-packages.html>
* <http://www.mathworks.de/de/help/matlab/matlab_oop/saving-class-files.html>

More about Matlab classes:

* <http://www.mathworks.de/de/help/matlab/ref/classdef.html>
* <http://www.mathworks.de/de/help/matlab/object-oriented-programming-in-matlab.html>
