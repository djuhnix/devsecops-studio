DevSecOps Studio Project
========================

> DevSecOps Studio is one of its kind, self contained DevSecOps environment/distribution to help individuals in learning DevSecOps concepts. It takes lots of efforts to setup the environment for training/demos and more often, its error prone when done manually. DevSecOps Studio is easy to get started, mostly automatic and battle tested during our Practical DevSecOps Courses at https://www.practical-devsecops.com/courses-and-certifications/

This project aims to refactor the existing DevSecOps Studio project to make it work locally with Vagrant and deployable on Proxmox.

See [README.off.md](README.off.md) for the original README.

## Getting Started

Create virtual environment and install requirements:

```bash
python3 -m venv .venv
source .venv/bin/activate
which pip
pip install -r requirements.txt
ansible-galaxy install -r requirements.yml
```



## Todo Features

- [ ] Provision the stack on a Proxmox server.
- [ ] Provision the stack on AWS using vagrant.
- [ ] Build Images using Packer and upload to vagrant cloud.
- [ ] Add Container scanning using clair.

## Contribution guidelines

* Fork this repo.
* Contribute (documentation/features)
* Raise a Pull Request (PR)

