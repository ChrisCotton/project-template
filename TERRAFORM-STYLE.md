## Terraform best practices
Terraform is an Infrastructure-as-Code configuration tool developed by HashiCorp.
for more information on Terraform, see TERRAFORM.md

### Variables
Variables should:
1. Be defined in variables.tf at the root of your project
1. Contain a description and type
1. Have a descriptive name

Variables may:
1. Contain a default, if appropriate
```

// Bad
variable "project_id"  {}

// Good
variable "project_id" {
    description     = "The project that will contain the infrastructure"
    type            = "string"
    default         = "acme-corp-it-[project]" 
}

```

### Structure
The root of a project that includes terraform code needs a terraform directory containing:
1. a main.tf file
1. a provider.tf file
1. a variables.tf file
1. an outputs.tf file
1. a modules directory containing any supporting modules for the main.tf
```
└── terraform
    ├── main.tf
    ├── modules
    │   └── module1
    │       ├── main.tf
    │       ├── variables.tf
    │       └── outputs.tf
    ├── outputs.tf
    ├── provider.tf
    └── variables.tf
```
### Comments
Comments should follow good grammatical style, starting with a capital letter
and end with a period.

Each resource should include at least a short comment about why it is included.

Single line comments are of the format:

`// This is a single line comment.`

Multiline comments are of the format:
```
/* 
Many lines of comments that are intended to explain a 
more complicated resource that might benefit by the 
additional explanation.
*/
```


### Equals

In stanzas, the `=` should match indentation with other `=`'s in that stanza:
```
// Bad
variable "project_id" {
    description = "The project that will contain the infrastructure"
    type = "string"
    default = "acme-corp-it-[project]" 
}

// Good
variable "project_id" {
    description     = "The project that will contain the infrastructure"
    type            = "string"
    default         = "acme-corp-it-[project]" 
}
```

### Modules

Modules should be contained in a `modules` directory and should be made
as generic as possible. Single use modules are not valuable to others.


```
// Bad
resource "google_compute_network" "gke-network" {
  name                    = "net-name"
  project                 = "acme-corp-it"
  auto_create_subnetworks = false
}

// Good
resource "google_compute_network" "gke-network" {
  name                    = "${var.vpc_name}"
  project                 = "${var.project}"
  auto_create_subnetworks = false
}
```

