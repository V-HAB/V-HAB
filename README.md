V-HAB / STEPS Bootstrapping Package
===================================

Downloaded from GITlab at <http://steps.lrt.mw.tum.de/>

Bootstrapping Repository
------------------------

Basic repository with the framework for V-HAB / STEPS. Contains four directories:

* core: central, shared V-HAB framework.
* lib: helper functions, pre/post processing, logging, GUI, date functions, ... (TBD)
* user: user-specific simulations
* data: user-generated simulation results (e.g. logs, plots, spreadsheets)

The core and lib packages are managed, i.e. most likely no changes should be done or can be committed to the online repository. Wiki of the according projects will soon contain some help.

How to get started with git / GITlab
------------------------------------

The following steps are only required the first time you setup your development environment. *If anything does not look or work as described, please contact your advisor.* 

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
* In the top menu select *Tools* -> *Create or Import SSH Keys*. This will open the PuTTY Key Generator.
* Click *Generate* and move the mouse around in the indicated area
* Once the key generation is completed, **enter a passphrase** (the password entered here has to be used again when adding the key to the available list of keys) and repeat it in the field below
* Click *Save public key* and save the file in a new directory anywhere on your system using the appendix `.pub`. 
* Click *Save private key* and save the file in the same directory as in the previous step, this time using the appendix `.ppk`. 
* In the top menu select *Conversions* -> *Export OpenSSH key* and save the file in the same directory as before without an appendix.
* Select the entire contents of the field *Public key for pasting into OpenSSH authorized_keys file* and copy them to the clipboard. 
* Close the PuTTY Key Generator. 
* In the browser navigate to your profile page at <http://steps.lrt.mw.tum.de/> and select the tab *SSH Keys*. 
* Click *Add new* and paste the copied key into the field *Key*, give it a title and click *save*.
* In the SourceTree top menu select *Tools* -> *Options* and in the *General* tab set the SSH Client to *OpenSSH* and click *ok*.
* Click *clone / new* and enter `git@steps.lrt.mw.tum.de:steps/steps-base.git` in the field *Source Path / URL*.
* Once you try to edit the field *Destination Path*, a window will pop up asking you, if you want to launch the SSH Agent. Say yes.
* Navigate to the folder you created earlier and select the file with the `.ppk` appendix (you probably have to enter the password you used when creating the key).
* Then click *Retry* in the next pop up window.
* The field *Repository Type* should now say *This is a Git repository*.
* Now select a destination path on your system where you want to store your files and press *clone*.
* SourceTree will now download all neccessary files to your machine. 

**SSH Keys Troubleshooting**: SourceTree seems to have some bugs regarding the SSH Key handling. Further help can be found on the [SourceTree Website FAQ](http://sourcetreeapp.com/faq/) -> *How do I set up SSH keys for authentication?* (last question). Further help in the [Bootstrapping Wiki - SSH Troubleshooting](http://steps.lrt.mw.tum.de/bootstrapping/wikis/ssh-troubleshooting) page.

See next section on how to use the bootstrapping repository, e.g. how to download the tutorial.

### Mac ###

See the [Mac Setup Wiki Page](http://steps.lrt.mw.tum.de/bootstrapping/wikis/setup-instructions-mac) for a step-by-step guide with screenshots. 

1. Download the SourceTree app at <http://www.sourcetreeapp.com/> (do not use the version from the Mac App Store as it is outdated). 
2. If the downloaded disk image was not automatically opened, (double) click the downloaded file. A Finder window should appear with both the *SourceTree* app and (pointing with a big arrow to) the *Applications* folder. 
3. To install SourceTree drag the *SourceTree* app and drop it onto the *Applications* folder. (You can then unmount the disk image and remove the downloaded file.) 
4. To setup the SSH keys (required for pushing changes from your local repository to the [STEPS server](http://steps.lrt.mw.tum.de)), open *Terminal* (either open Spotlight search and enter `Terminal` or launch Terminal from *Applications* -> *Utilites*). 
5. In the Terminal command prompt, enter `ssh-keygen -C 'email@address.com'` (where `email@address.com` is **your STEPS GITlab email address**). Press `Enter` to start the command. 
6. The SSH key generator will ask for a file name, just press `Enter` to use the default file name. 
7. You will then be asked for a passphrase that you can assign freely to protect your SSH key file (please use a **strong password**!). This password may be asked for when pushing commits to the STEPS server (however you can save the password in your Mac OS keychain). Please remember that this password cannot be recovered (if you forget the password, you will need to create a new keyfile, see *steps 4-8*, and update your STEPS GITlab profile, see *steps 9-11*)! Press `Enter` after typing in the password (while you type, you will neither see the password nor any indication that you are actually entering anything; this is intentional albeit confusing at first). 
8. You will be asked to retype your chosen passphrase. Press `Enter`. Finally a random art image will be displayed. 
9. Then you have to add the public key to your STEPS GITlab account. First, enter `pbcopy < ~/.ssh/id_rsa.pub` in the Terminal command prompt and confirm with `Enter`, this will copy your public key to your clipboard (there will be no confirmation message in the Terminal). 
10. In the browser, navigate to your profile page at <http://steps.lrt.mw.tum.de/> and select the tab *SSH Keys*. 
11. Click *Add new* and paste (`CMD + V`) the copied key into the field *Key* (a cryptic text beginning with `ssh-rsa` and ending with your STEPS GITlab email address should appear; if not, repeat *step 9*), the title should then automatically be your STEPS GITlab email address. Click *save*. (You can quit the Terminal after successfully completing this step.) 
12. Launch *SourceTree* from the *Applications* folder. 
13. In the *Welcome* window, enter your full name and your STEPS GITlab email address (e.g. `username@mytum.de`). Make sure that both checkboxes are ticked, then click *Next*. 
14. Skip the *Connect to online services* and *Find local repositories* form by clicking *Next* and *Finish*. 
15. You can now create or clone repositories. Continue with the example provided in *Clone a repository (Mac)* below to download the files you need to get started (you can skip *step 1* and just copy the example SSH address in *step 2*). 

### Clone a repository (Mac) ###

The following steps are the same for every new Repository you want to clone from the STEPS GITlab server. 

1. Visit the page of the project you want to clone (e.g. <http://steps.lrt.mw.tum.de/bootstrapping>). 
2. Locate and copy the SSH address of the repository at the top of the project timeline (e. g. `git@steps.lrt.mw.tum.de:steps/steps-base.git`). 
3. In the SourceTree *Bookmarks* window, click the top left icon which says *Add repository* on hover (or select *File* -> *New / Clone* from the top menu). Make sure the *Clone repository* tab is selected. 
4. In the field *Source Path / URL*, paste (`CMD + V`) the SSH address of the repository you want to clone (see *step 2*). 
5. Choose a bookmark name (in our example, `bootstrapping` is pre-selected, I suggest changing this to `STEPS` or `STEPS bootstrapping`). This is the name that will be displayed in the *Bookmarks* window of SourceTree. 
6. Choose a *Destination Path* by clicking the ellipsis (`...`) or entering the path directly into the field. I recommend adding a new folder *STEPS* in the *Documents* directory (i.e. destination path is `/Users/{yourusername}/Documents/STEPS`). 
7. Make sure that under *Advanced options* (may need to be opened by clicking the triangle) the checkboxes *Recurse submodules* and *Get working copy* are ticked. Leave the rest as-is. 
8. Before clicking *Clone*, make sure that it says `This is a Git repository` below the *Source Path / URL* field. Finally a progress window will appear, and as soon as it says `Completed successfully` you're good to go and you can click *Close*! 

To view a repository, double-click on its entry in the SourceTree *Bookmarks* window (when subsequently launching SourceTree, a repository may already be opened, check the window title to see which one it is!). Clicking on `master` under `Branches` will list the (local) commit history of the opened repository. To see the current status on the STEPS server, click on `origin/master` under `Remotes` (you may need to open the branches by clicking on the triangle). 


Getting Started Programming
----------------

### Create your user folder ###

Once you have successfully cloned the bootstrapping project onto your hard drive, navigate to the `user` folder. There create a folder using the following naming  scheme: `+username`. Your username is the first two letters of your last name and the first two letters of your first name. So if your name is Max Mustermann, your username would be `muma`.

### Check out the tutorials! ###

Inside the directory `user/+tutorials` you will find a few tutorials to get you started. Some of them also have read me files like the one you are reading right now, be sure to check them out. To run one of the tutorials, enter the following command into the MATLAB command window: For example the "simple_flow" tutorial is `vhab.exec('tutorials.simple_flow.setup')`. Once the simulation has completed (you will see this by the outputs in the command window), you can plot the results of your simulation by entering `oLastSimObj.plot()` in the command window. Now you can play around with some of the parameters of the systems inside the tutorial and see what happens. 

### How to update your local files ###

If you want to update your local working copy files to the current version, select the bootstrapping repository in SourceTree and press "pull". This should load all new or changed files onto your machine. 

### To create a new simulation project: ###

* Go to the Gitlab server at `steps.lrt.mw.tum.de` and create a new project. The following points assume your username is `bobo` and your project is called `spacestation`.
* Create a local directory inside the STEPS `user` folder with your username preceeded by a plus sign, e.g. `user/+bobo`. Inside that directory create another one with your project name also prefixed by a `+`, e.g. `user/+bobo/+spacestation`. I.e. the pattern is `{steps-base}/user/+{username}/+{projectname}`).
* Put your project files (classes, functions) and folders (package directories) **only** into the project directory (e.g. in `user/+bobo/+spacestation`). Do **not** add any additional files like documents, papers, results, plots, etc. to the project directory. For results and plots, use the `data` directory in the STEPS base folder.
* Every system needs a `setup.m` that initializes a simulation in the project directory, e.g. `/user/+bobo/+spacestation/setup.m`. The simulation can then be started by executing `vhab.exec('bobo.spacestation.setup');` in the MATLAB console. Your classes can be accessed with e.g. `bobo.spacestation.myClass()`.
* Use the SourceTree app or the GIT console to initialize a GIT directory within `/user/+bobo/+spacestation`. Add the remote repository (`steps.lrt.mw.tum.de:bobo/spacestation.git`). Commit & push.

### Commiting and pushing files to the repository ###

You should do this early and often to make sure none of your work is lost.

Once you are at a point where you would like to commit the changes you have made to the code, you have to first commit the changes to your local repository. SourceTree lets you do this for several files at once so you don't have to repeat the process for every change you make. 

* First open SourceTree and navigate to the repository tab in which you have made changes.
* If you click on *Working Copy* inside the *File Status* section on the left you should see some files marked as modified in the portion of the window labled *Working Copy Changes*
* To prepare for the commit you have to add the modified files to a list of files that will be commited together.
* To do this, click the *Add/Remove* button in SourceTree.
* A warning may appear saying *This action will remove all files missing from your working copy, and add all new ones.* I'm really sure what this means, but since I am sure that I don't have any missing files, I click *ok*.
* Now the changed files in your local repository will appear in the window section labeled *Staged Changes*. 
* Unless you want to keep working and change other files, you are now ready to commit the files to your local repository version control. 
* To do this, click the *Commit* button in SourceTree.
* A window will appear showing you all of the changes you have made to which files. At the top of this window is a text box for the commit message. It is very important that you enter a meaningful message here because it will help you track your changes later on and it will also let other users see, what has been changed. When writing the commit message the first word should be a keyword indicating what action you have performed (i.e. *add*, *edit*, *remove*, *fix*). If you look into the commit history of this readme file, you will see entries like *edit readme to include commit instructions*.
* Press *commit* in the bottom right corner of the window if you are ready to commit.
* After the process is complete, your local master branch is one step ahead of the master branch on the STEPS server. This is because at this point you have only commited your changes locally. To update the files on the STEPS server you need to *push* the changed files. To do this click the *push* button in SourceTree.
* A window will appear in which you can make some selections. You should push to the *origin* repository (should be the only available option) and you should push your local master branch to the remote master branch. The checkbox labeled *Track?* should have a black square in it (I don't know what this means either...) and at the bottom of the window both *Select All* and *Push all tags* should be selected.
* Once you have verified all this, press *ok*
* After pushing your local master branch should match the *origin* master branch on the server and the process is complete. 


Stage, commit, push...


About Matlab OOP
----------------

More about Matlab packages / class organization:

* <http://www.mathworks.de/de/help/matlab/matlab_oop/scoping-classes-with-packages.html>
* <http://www.mathworks.de/de/help/matlab/matlab_oop/saving-class-files.html>

More about Matlab classes:

* <http://www.mathworks.de/de/help/matlab/ref/classdef.html>
* <http://www.mathworks.de/de/help/matlab/object-oriented-programming-in-matlab.html>
