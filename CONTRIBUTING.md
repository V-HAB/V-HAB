# How to contribute

We welcome contributions in two forms: 

* **Issues** (aka Bugs, Reports, Requests, …) are for bug reports and feature requests in text form. When [opening a new issue]($repo#new-issue), please describe your problem as detailed as possible to help in addressing it promptly. For **bug reports**, make sure to include e.g. *steps-to-reproduce* (STR), the *expected result*, and the *actual result* that the current code produces. For **feature requests**, please explain *why* you need a particular change and how existing functionality can not meet your requirements. 
* We use **Merge Requests** (MR) as a [way to contribute code changes](#contributing-code-changes). The changes can improve existing code or extend the capabilities of the system architecture. Please note that any contribution will be carefully reviewed and may be declined if the changes do not follow our [coding guidelines](#coding-guidelines) or [git conventions](#git-conventions) – you can fix them later and re-submit a MR but that means extra work for everyone. MRs may also be declined if the proposed changes do not fit into the scope and planning of the project – when in doubt, contact a project supervisor and/or create a feature request (and assign it to yourself) before spending too much time on something that may be declined.

Both forms of contribution apply to external as well as internal contributions.

## Contributing code changes

0. [Create a new issue]($repo#new-issue) for the problem you are trying to solve if one does not exist yet. Assign the issue to yourself. Make sure the changes you are about to make are in line with the project goals (e.g. by talking to project supervisors; please share any resolutions by posting them in a comment on the issue).
1. Read the [coding guidelines](#coding-guidelines) & [git conventions](#git-conventions) to learn about the way we expect contributions to be.
2. [Fork this repository]($repo#create-fork) and [clone the forked repository](docs/installation-and-configuration.md#cloning-a-repository) to your machine if you have not forked it yet. See the instructions on [how to set up your cloned fork](#how-to-create-a-fork).
3. Create a new branch from master in your forked repository for every isolated feature development or bug fixing work. See the [conventions for branching](#branching-conventions).
4. Code away, and remember to commit early and often. Your [commit should follow the recommendations](#how-to-create-good-commits) and the [commit message should reflect your intentions](#how-to-write-good-commit-messages), i.e. state *why* you made your changes. Don’t forget to push your changes!
5. [Create a merge request]($repo#new-merge-request) from your branch to either the current bugfix or `develop` branch. In the title and/or description, include the corresponding issue number and a short summary of the changes, how you solved the problem and why you chose to do it this way.
6. Fix any followup issues that arise during review by committing to the same branch (the MR is automatically updated). For long-running branches, you may be asked to [rebase your branch on the latest master](#how-to-rebase-a-branch) (or other branch).


# Development rules

Make sure to create a [new branch before starting development](#branching-conventions) and [committing](#how-to-create-good-commits) your first changes.

## Coding guidelines

(This section is work-in-progress.)

### Naming conventions

* package names are lower case and words may be separated by an underscore (e.g. `lumped_parameter`, *not* `LumpedParameter` nor `lumpedParameter`)
* class names are upper camel case (e.g. `MassFlow`, *not* `massFlow` nor `mass_flow`)
* functions and methods are lower camel case, start with a verb (e.g. get, set, load, …), and state what is happening inside the function resp. what the return value is (e.g. `getSpecificHeatCapacity`, *not* `GetHeatCapacity` nor `heat_capacity`)
* variables containing boolean (`true`/`false`) values follow general variable naming conventions (see below) but sound positive and include has/have or is/are so the name sounds like a question and its value is the answer (e.g. `bIsCompressible` or `abIsPhaseCritical`, *not* `bIncompressible` nor `Compressible`)
* variables are lower camel case, start with a type descriptor, and state their content (e.g. `fMassFraction` or `mfMassFractions`, *not* `mass_fraction` nor `afmassfraction`)


## git conventions

(This section is work-in-progress.)

### Development model

The model used for development with git is release-based (version format is `vX.Y.Z`) and builds on a mix-and-match of various models (e.g. GitHub Flow, Git Flow, Gitlab Flow, …):

* release versions are tagged, tags are non-moving
* `master` contains latest „public“/stable release that should be used for other projects building upon this project
* the next bugfix version (i.e. the `Z` increments) to be merged to `master` is in a dedicated bugfix branch and will be merged about every 2-3 weeks
* `develop` contains code for next minor (the `Y` increments) version and is merged to `master` roughly every 6 months (major versions may or may not get a separate branch)
* yet-unmerged/work-in-progress [feature/bugfix branches](#branching-conventions) are (mostly) created from `master` and merged to `master` or `develop` after the corresponding MR is given the go-ahead

(This section is work-in-progress.)

### Branching conventions

* One feature/bug, one branch: Every set of standalone changes should be committed to a new branch. *Do not mix unrelated ([non-trivial](#what-is-a-trivial-change)) changes within one branch* that you intend to get merged into upstream code. 
* Say what it does: The name of the branch should hint at what the branch contains. Do add „WIP“ to the beginning of the branch name (e.g. `WIP-bugfix-v2.1.3`) if you do *not* intend to land the branch in `master` or `develop`, i.e. when it’s a throw-away branch or you will [rebase the branch before actually merging](#git-rebase-conventions). 
* Base on `master`: Every branch should start from the latest commit on `master` to reduce the possibility of merge conflicts or merging unwanted commits. The *only* exception is when a branch builds upon another branch that has not yet been merged to `master` (so this exception applies to branches building upon changes that were only merged to the `develop` branch yet).

### What is a trivial change?

Any change that alters the way of execution, result, or API is non-trivial. This leaves the following changes as being trivial:

* comment-only changes
* whitespace changes (i.e. adding/removing blanks or newlines)
* deleting dead (unreachable) code – make sure the code is really, *really* unreachable!

These trivial changes can be committed to a general cleanup/comment/docs branch that will be rebased and merged regularly.

(This section is work-in-progress.)

### How to create good commits

See also the next section with [tips for good commit messages](#how-to-write-good-commit-messages).

(This section is work-in-progress.)

### How to write good commit messages

> The commit message should reflect your intention, not the contents of the commit. The contents of the commit can be easily seen anyway, the question is why you did it.

You may add a reference to issues in the commit message, which are then automatically linked. E.g. when adding „fixes #123“ to the commit message, the issue #123 will be closed automatically.

(This section is work-in-progress.)

### How to create a fork

Forks are personal copies of another repository (the latter is often called „upstream“ relative to the fork). They are primarily used for committing changes to the original code that are later [submitted for review to the upstream repository using Merge Requests](#contributing-code-changes) (or similar techniques).

(This section is work-in-progress.)

## git rebase conventions

(This section is work-in-progress.)

### When (not) to rebase/amend

Rebasing and amending changes commit IDs and thus the history of your branch. Once you pushed your commits to a server, avoid changing history since you don’t know if anybody else has pulled your code and may pollute your carefully cleaned-up history!

When you want to clean up your branch history or rebase it to branch off the latest 

(This section is work-in-progress.)

### How-to-rebase-a-branch


# Final words

Don’t be afraid to make mistakes, we will assist and guide you through your first contributions so you can learn. Hack away!