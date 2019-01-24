## Terraform best practices
Terraform is an Infrastructure-as-Code configuration tool developed by HashiCorp. 

For a detailed introduction, see the
[Terraform docs](https://www.terraform.io/intro/index.html)

For a quick-start, it's sufficient to know the following:
* Terraform uses a JSON-like language (HCL, or Hashicorp Configuration Language) to describe infrastructure. 
* When you run `terraform apply` for the first time, it will use that description to identify which pieces of infrastructure need to be configured first, and then it will make the necessary API calls in the appropriate order.
* Terraform uses the concept of a "state file" (terraform.tfstate) as its database to keep track of the resources it has previously created. 
* Removing the "state file" will remove Terraform's understanding of the current environment.
* Subsequent runs of `terraform apply` will generate API calls based reconciling the contents of the state file to the HCL resource descriptions. 
* **If your state file is lost or corrupted, you will have to manually manage any resources previously defined therein** (Or use advanced Terraform features to re-import and reconcile the state file) - for this reason, storing the state file remotely is recommended if collaborating on a Terraform-managed project with others.
* The terraform command operates on all files in the working directory that have a .tf suffix. It aggregates them and evaluates the result, while attempting to resolve the dependency tree. There are generally accepted naming convetions for common functonality, these conventions aren't enforced by terraform.


### Run terraform fmt and terraform validate frequently
Terraform provides built-in tools for beautifying and linting code. The
most useful are the `terraform fmt` and `terraform validate` commands.
Both of these tools must be passing before you submit code for review.


### Use a main.tf file as the entrypoint.
If your configuration only requires a single file, name it main.tf. If
it's helpful to break some components out, put the top-level components in
main.tf and reference modules contained in other files. This is a common
naming convention that will make the codebase easier to consume by the
community.


### Use a provider.tf to configure the cloud provider:
It's helpful to define a provider.tf file that includes only provider stanza.
Providers are effectively "drivers" for cloud platforms. In our case, we use
the google provider and generally pass it:

* The version of the provider to use
* The default project name we're working in (if applicable)
* The default region we're working in (if applicable)

See https://www.terraform.io/docs/providers/google/index.html

```
provider "google" {
  version 	= "~> 1.12"
  project     = "my-gce-project-id"
  region      = "us-central1"
}
```

The provider can also be used to specify cloud credentials, but the preferred
method is to let it detect them based on environment variables.


### Define input variables in variables.tf

It's convenient to declare your variables in their own file, particularly when you start writing more complex modules.

The description field for each variable is helpful as inline documentation as well was exportable for generated docs via tools like [terraform-docs](https://github.com/segmentio/terraform-docs)

```
variable "vpc_name" {
  description = "The name of the primary VPC in which to home the GKE cluster."
  type = "string"
  default = "kube-net"
}

variable "subnet_name" {
  description = "The name of the subnet in which to home the GKE master."
  type = "string"
  default = "kube-net-subnet"
}

...
```

Variables that don't have defaults specified will be interpreted as required.
Most `terraform` commands will prompt you for required variables whose values haven not been specified as command line arguments
or via a .tfvars file.

Specifying variable values on the command line is done with -var arguments, eg.:
```
$ terraform [command] -var "cluster_name=gke-cluster" -var 
"cluster_zone=us-west1-a" -var "location=us-west1" -var "project=samuelmi-hlmsmn" -var "gce_ssh_user=`whoami`"

```

For more information, see: https://www.terraform.io/intro/getting-started/variables.html
* Use a .tfvars file to define any variables that are relatively constant and won't
need to be overridden 
* For complicated plans, utilize `terraform plan -var "var1=val1" -var "var2=val2" -var "var3=val3" -var "var4=val4" -var "var5=val5" -out complicated_plan` and then run `terraform apply complicated_plan` to apply it. This will allow you to inspect the output before actually applying it.

### Define outputs in a single outputs.tf

Often, you'll want to get a quick view of all the outputs provided by a terraform configuration. 
Storing them all in one place saves having to grep the entire project.

Outputs don't have a "description" field, but should be documented nonetheless:
```
// The default IP address created for an instance 
output "default_ip" {
  value = "${google_compute_address.default.address}"
}
```

### Comment liberally

Since our code is meant to be a learning resource for the community, we should not assume much
familiarity with Terraform or Google Cloud in our comments.

Four cases are worth highlighting:

#### Resource definitions

Resource comments should describe the intention of the resource (ie why we're creating it), and 
include a link to the resource's docs.

```
// This is the network in which we'll install the GKE cluster
// see: https://www.terraform.io/docs/providers/google/r/compute_network.html
resource "google_compute_network" "gke-network" {
    name            = "${var.vpc_name}"
    project         = "${var.project}"
    auto_create_subnetworks = false
}
```

#### Resource sub-stanzas

Complex resources may have multiple stanzas that should be described to the end user.
Since the parent resource will link back to the docs, we don't have to include another link here. 
But we should still state our intention.

```
  // This activates IP aliasing and is required for private clusters.
  // As of now, only pre-allocated subnetworks (custom type with
  // secondary ranges) are supported.
  ip_allocation_policy {
    cluster_secondary_range_name = "secondary-range"
  }
```

#### Module definitions

Modules are reusable groups of configuration, somewhat analogous to functions in a 
procedural programming language. Here are four key aspects to modules:

1. Module input variables using their "description" fields
1. All resources defined within the module as per the standard described above.
1. The module's overall purpose should be documented at the top of it's main.tf file.
1. All module outputs should include a brief description of their purpose.


## Modules

As mentioned previously, terraform allows common configuration to be abstracted as "modules".
These are simply groups of resource definitions that have been parameterized with a single
set of variables.

Beyond their benefits as reusable components, modules are also useful in organizing
configuration into coherent components in much the same way functions can serve
a dual role for abstraction and encapsulation in other languages.

The use of modules in our codebase is unlikely to be mandated, but it may 
save us all time to standardize a few common modules for reuse in each 
stream of development.

For more information see: https://www.terraform.io/docs/modules/usage.html


## Managing the Terraform state file

Terraform's internal representation of all provisioned infrastructure is stored
as JSON in a "state file". By default this file is stored locally as terraform.tfstate.

Keeping the state file in sync with provisioned resources is critical to avoiding major 
headaches when working with Terraform. And the easiest way to keep it in sync is to follow
a few simple rules:

* Do not manually edit, or delete resources that were created with terraform
* Do not share state files unless you also share access and responsibility over
the cloud resources it references. 
* If you refactor your terraform config, and do not want to update provisioned resources
use the [terraform state](https://www.terraform.io/docs/commands/state/index.html) command 
to update the state file.
* **Do not check your statefiles into version control**. If you intend to share state,
use a remote backend like [Cloud Storage](https://www.terraform.io/docs/backends/types/gcs.html)
* Add terraform.tfstate to .gitignore to prevent it from being checked in to git
* **Do not kill a `terraform apply` or `terraform destroy` command before it has completed. Doing so 


## Recommendations for .gitignore:
1. **/.terraform/* (this is the directory that contains the installed provider plugins)
1. *.tfstate* (all statefiles)
1. crash.log (any crash logs)

### Terraform Code Style:
see TERRAFORM-STYLE.md

