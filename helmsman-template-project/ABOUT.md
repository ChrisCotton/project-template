# About This Project

Note: Do not include this file or the 'linting' folder in your project.

## Helmsman Template Project
The Helmsman Template Project is a template for starting new projects for Helmsman
POCs. All Helmsman projects, at minimum, must have the following files:

1. README.md
1. LICENSE file
1. CONTRIBUTING file
1. Makefile
1. hack directory and its contents
1. CODE-OF-CONDUCT.md

Examples of the above files and directories are contained in this project.  Within
your project you should use the Makefile.template file instead of the one named
Makefile.  The Makefile.template excludes some specific targets that are used
for testing the template itself and are not needed in other projects.  Copy this
file to your project directory and remove the '.template' extension.  Additionally,
the test/test_verify_boilerplate.py file can be excluded from your projects as it
is just used in testing the template itself.

## Linting
The makefile in this project will lint or sometimes just format any shell,
Python, golang, Terraform, or Dockerfiles. The linters will only be run if
the makefile finds files with the appropriate file extension.

All of the linter checks are in the default make target, so you just have to
run

```
make -s
```

The -s is for 'silent'. Successful output looks like this

```
Running shellcheck
Running flake8
Running gofmt
Running terraform validate
Running hadolint on Dockerfiles
Test passed - Verified all file Apache 2 headers
```

The linters
are as follows:
* Shell - shellcheck. Can be found in homebrew
* Python - flake8. Can be installed with 'pip install flake8'
* Golang - gofmt. gofmt comes with the standard golang installation. golang
is a compiled language so there is no standard linter.
* Terraform - terraform has a built-in linter in the 'terraform validate'
command.
* Dockerfiles - hadolint. Can be found in homebrew

The **linting** directory has example files to test the makefile. Only the maintainer of the makefile in this project needs to worry about that directory.

## Terraform troubleshooting section

Every Terraform troubleshooting section should have the following problem/solution pair:

```
**Problem:** The install script fails with a `Permission denied` when running
Terraform.

**Solution:** The credentials that Terraform is using do not provide the
necessary permissions to create resources in the selected projects. Ensure
that the account listed in `gcloud config list` has necessary permissions to
create resources. If it does, regenerate the application default credentials
using `gcloud auth application-default login`.
```

## Housekeeping Items

1. Replace all instances of "Master" with "Control Plane" or, if necessary, "Control Plane (Master)"
1. Follow Google coding standards and style guides https://google.github.io/styleguide/.
1. Bash and Shell scripts must have the ".sh" extension or the boilerplate checker will not function.
1. Use linters and formatters.  For instance pylint and yapf for python.
1. Run terraform fmt and terraform validate on all modules
1. Please include the link to signup for a Google Cloud Free account. https://cloud.google.com/
1. Include a "Supported Operating Section" listing macOS, Linux, and (Google Cloud Shell)[https://cloud.google.com/shell/docs/].
1. Include a Table of Contents that does not have the "Table of Contents" section or the document title in it, and is unidented all the way to the left.
1. Run make and ensure the headers are correct
1. Whitespace and tabs, must be consistent with the style style guide for the language in question.
1. "#!/bin/bash -e" everywhere
1. Check the container labels I am doing with the Cassandra contain and add labels, and a TODO to update the github project name.
1. Check that all projects have the base files.  See above.
1. Markdown code blocks should use the appropriate language hint, eg: "```console" for shell scripts
1. Internal names like Helmsman and Cardinal should not appear anywhere in the code or images
1. Screenshots and images should show generic names for all resources. Project and cluster are often named after team members and should be photoshoped out.
