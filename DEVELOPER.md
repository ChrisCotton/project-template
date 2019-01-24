# Developer HOWTO

These are some basic instruction on using git-on-borg.

## Google Style Guides

The general style guide is located at https://google.github.io/styleguide.  For this project please take a look at the shell style guide at https://google.github.io/styleguide/shell.xml

## Setting up git

### Setup Password

You need to execute a bash script to configure your access to git-on-borg.
Go to
[https://partner-code.googlesource.com/new-password](https://partner-code.googlesource.com/new-password).
This page will provide you the script that needs to be executed in a command
line bash shell.

Script example:

```
set +o history
touch ~/.gitcookies
chmod 0600 ~/.gitcookies

git config --global http.cookiefile ~/.gitcookies

tr , \\t <<\__END__ >>~/.gitcookies
partner-code.googlesource.com,FALSE,/,TRUE,2147483647,o,git-example.google.com=1/DcIQju4uv6z3xHCl4z9D2bVSIUZd20tqc4KKGAtmakk
partner-code-review.googlesource.com,FALSE,/,TRUE,2147483647,o,git-example.google.com=1/DcIQju4uv6z3xHBlzz9DMbVSZUZd20tdc4KKGBtmakk
__END__
set -o history
```

### Configure Git Email Address

You need to configure your LDAP google.com email address to be used by git.
Replace `ldap` with your actual username, for instance; "chlove@google.com".

`git config --global user.email "ldap@google.com"`

## Migrating Existing Repos

All repos in gflocks need to be migrated to git-on-borg.  Each existing repo
will live in a new folder, and will be migrated to GitHub as individual projects.

### Clone the new repo

Execute the following command.

`git clone https://partner-code.googlesource.com/helmsman-cardinal`

### Copy your code from the old repo to the new repo

Copy the folder containing your git repo to the new project that you just
checked out.

We need a new folder for each git repo. Do not copy the .git folder.
Just in case cd into your POC directory, and `rm -rf .git`

### Create a hook in the new repo

This hook will configure an id that Gerrit requires. Run below command as is to create a hook.

```
curl -Lo $(git rev-parse --git-dir)/hooks/commit-msg \
 https://gerrit-review.googlesource.com/tools/hooks/commit-msg ; \
 chmod +x $(git rev-parse --git-dir)/hooks/commit-msg
```

If above command throws an error, continue with code push and follow the instructions shown.


## Code Review Workflow

Our source code will be reviewed in a tool called Gerrit.  This website is
located at:
[https://partner-code-review.googlesource.com/c/helmsman-cardinal/](https://partner-code-review.googlesource.com/c/helmsman-cardinal/).

### Create New Code Review

Do not push multiple commits, only push one commit.  Each commit is a different
code review.

```
git add .
git commit -m "new POC added"
git push origin HEAD:refs/for/master
```

The push will print out the URL for the code review in Gerrit.


### Code Review

Your code is reviewed, and commented on. You will get an email.

TODO: more instructions here.

### Create a new patch

Once you make the changes to your code you need to amend to the origin commit.
The following commands will update and push new code for review.

```
git add .
git commit --amend
git push origin HEAD:refs/for/master
```


### Marking Code as Work in Progress

When you do not want an immediate code review, you can follow these steps.

From a terminal window, mark the change as a work in progress by adding %wip at
the end of a git push command:

```
git push origin HEAD:refs/for/master%wip
```

When you’re ready for other contributors to review your change, you can unmark
the change using the following command:

```
git push origin HEAD:refs/for/master%ready
```

### If you forget to --amend...

TLDR; Squashing is equivalent to `commit --amend` as far as Gerrit is concerned.

In the event that you forget to commit --amend, you'll end up with multiple commits on your ref, which will cause Gerrit to create aditional changesets the next time you push.

This can be fixed with a standard squash operation to combine all commits into the original. Note that this process works regardless of the
reason of having multiple commits.

1. Use `git log -$NUM` to find the SHA of the parent of your first commit. For example, if you've made 4 commits, use `git log -5` to find the SHA1 of the parent.
1. Perform an interactive rebase back to the parent commit: ``` git rebase -i $PARENT_COMMIT_SHA ```
1. You'll be prompted to choose the commits you want to rebase. All but the first commit should be "squashed". For example:
```
$ git log -3
commit 02b05dff1a721dbecddc7b807a4b24315e62750e (HEAD -> upstream-master)
Author: Robin Percy <kpercy@google.com>
Date:   Wed May 16 13:59:38 2018 -0700

    Instructions for squashing 2

    Change-Id: I696d4fb6c7610fda9166fcb4e7163be633a3a0c1

commit f314ed5adcb52bff5106078d4e1a4e77b957fa1b
Author: Robin Percy <kpercy@google.com>
Date:   Wed May 16 13:57:48 2018 -0700

    Instructions for squashing

    Change-Id: If530cc185c3ec94e6cc46d641a09344596c45f37

commit 416a22e3e8279ea6357294411a0841927c0d0336 (origin/master, origin/HEAD)
Author: chrislovecnm <chlove@google.com>
Date:   Wed May 16 11:18:07 2018 -0600

    adding new directory

    Change-Id: I12c8b9afed40cf922b620a75b3f1a6705068281c


// Start the rebase
$ git rebase -i 416a22e3e8279ea6357294411a0841927c0d0336
  ------------ Editor Begin --------------------
  1 pick f314ed5 Instructions for squashing
  2 squash 02b05df Instructions for squashing 2
  3
  4 # Rebase 416a22e..02b05df onto 416a22e (2 commands)
  5 #
  6 # Commands:
  7 # p, pick = use commit
  8 # r, reword = use commit, but edit the commit message
  9 # e, edit = use commit, but stop for amending
 10 # s, squash = use commit, but meld into previous commit
 11 # f, fixup = like "squash", but discard this commit's log message
 12 # x, exec = run command (the rest of the line) using shell
 13 # d, drop = remove commit
 14 #
 15 # these lines can be re-ordered; they are executed from top to bottom.
 16 #
 17 # if you remove a line here that commit will be lost.
 18 #
 19 # however, if you remove everything, the rebase will be aborted.
 20 #
 21 # note that empty commits are commented out

:wq
  ------------ Editor Ends --------------------

// You will be prompted to edit the combined commit comment.
// Edit it to include only the original Change-Id
// Eg, DELETE lines 8 - 12 in the below message

  ------------ Editor Begins --------------------
  1 # This is a combination of 2 commits.
  2 # This is the 1st commit message:
  3
  4 Instructions for squashing
  5
  6 Change-Id: If530cc185c3ec94e6cc46d641a09344596c45f37
  7
  8 # This is the commit message #2:
  9
 10 Instructions for squashing 2
 11
 12 Change-Id: I696d4fb6c7610fda9166fcb4e7163be633a3a0c1
 13
 14 # Please enter the commit message for your changes. Lines starting
 15 # with '#' will be ignored, and an empty message aborts the commit.
 16 #
 17 # Date:      Wed May 16 13:57:48 2018 -0700
 18 #
 19 # interactive rebase in progress; onto 416a22e
 20 # Last commands done (2 commands done):
 21 #    pick f314ed5 Instructions for squashing
 22 #    squash 02b05df Instructions for squashing 2
 23 # No commands remaining.
 24 # You are currently rebasing branch 'upstream-master' on '416a22e'.
 25 #
 26 # Changes to be committed:
 27 #›      modified:   DEVELOPER.md
 28 #
:wq
  ------------ Editor Begins --------------------

// When done, you should get a message like:
[detached HEAD 3843b83] Instructions for squashing
 Date: Wed May 16 13:57:48 2018 -0700
 1 file changed, 19 insertions(+)
Successfully rebased and updated refs/heads/upstream-master.
kpercy-macbookpro:helmsman-cardinal kpercy$

$ git push origin HEAD:refs/for/master%wip
```


For more information on how this works, see https://git-scm.com/book/en/v2/Git-Tools-Rewriting-History

### Multiple People Working on the Same Ref

If you need multiple developers working on a WIP ref in follow this work flow:

A developer needs to follow the above steps from creating `wip` ref.

Developer two then will follow the next steps:

1. Go into the Gerrit code review dashboard
1. Find the Ref that is currently being reviewed
1. On the wip page go to the Download Link, which includes the command that is marked as check, which is a `git fetch command`
1. inside your cloned repo execute: `git fetch https://partner-code.googlesource.com/helmsman-cardinal refs/changes/48/109448/1 && git checkout FETCH_HEAD`
1. make changes locally
1. execute `git add`
1. execute `git commit --amend`
1. execute `git push origin HEAD:refs/for/master%wip`
1. make more change
1. execute `git add`
1. execute `git commit --ammend` 

## Disable Santa
Go to https://support.google.com/techstop/answer/2690761 and follow instructions according to the platform. 
