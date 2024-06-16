# Cloud Setup

## Azure

### Prerequisites

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
* [Terraform](https://www.terraform.io/downloads.html)
* [Ansible](http://docs.ansible.com/ansible/latest/intro_installation.html#installation)

### Setup

1. login to Azure and create a service principal

```bash
az login
az ad sp create-for-rbac --name DevSecOpsStudio --role contributor --scopes /subscriptions/<subscription_id>
```

2. Create a `terraform.tfvars` file with the following content

```hcl
subscription_id = "<subscription_id>"
client_id = "<client_id>"
client_secret = "<client_secret>"
tenant_id = "<tenant_id>"
```

3. Run the following commands

```bash
terraform init
terraform apply
```

4. Once the terraform apply is successful, you can ssh into the machine using the following command

```bash
ssh -i ~/.ssh/<azure_rsa> <azureuser>@<public_ip>
```
