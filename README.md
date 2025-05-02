# Digital Earth Terraform Templates

Infrastructure as code for the modern Digital Earth

## Overview

TODO: Document stuff

## Manual steps

You need to create some secrets on AWS manually, then refer to them in Terraform.

The list of manual secrets is in [secrets.md](secrets.md).
These should be deployed to your preferred operating region i.e. `us-west-2`

Route53 hosted zones for each environment need to be created manually, and 
placeholder text in the `main.tf` terraform (tf) file to match the created hosted
zones.


## Environment setup

Install the Terraform CLI and login to Terraform Cloud using `terraform login`.  
Follow the prompts.  You will need a [Terraform Cloud](https://app.terraform.io) 
account and have created an access token to perform this command.

Within Terraform Cloud, you will need to manually create a workspace for each 
environment with the working directory set to either `staging` or `production`.

You should also update the `DigitalEarthExample` and `org-staging` or `org-prod` 
placeholder text in the `main.tf` terraform (tf) file to match the created workspaces.

## Authentication

Note that an Identify Provider was manually added to AWS using
[this](https://aws.amazon.com/blogs/apn/simplify-and-secure-terraform-workflows-on-aws-with-dynamic-provider-credentials/)
documentation.

You can see the
[identity provider](https://us-east-1.console.aws.amazon.com/iam/home?region=ap-southeast-2#/identity_providers)
on the AWS console.

Next we set up a role with a custom role trust policy, as documented above.
The [role](https://us-east-1.console.aws.amazon.com/iam/home?region=ap-southeast-2#/roles/details/TerraformCloudRole)
can be accessed on the console here.

Finally we export two variables in Terraform Cloud:

* `TFC_AWS_PROVIDER_AUTH`, which is set to `true`
* `TFC_AWS_RUN_ROLE_ARN`, which should have the ARN
  `arn:aws:iam::AWS_ACCOUNT_ID:role/TerraformCloudRole` from the role above.

## One off tricks

If you get the error:

> AuthFailure.ServiceLinkedRoleCreationNotPermitted: The provided credentials do not have permission to create the service-linked role for EC2 Spot Instances

do this on the command line with a privileged user.

`aws iam create-service-linked-role --aws-service-name spot.amazonaws.com`

[Reference here](https://karpenter.sh/docs/troubleshooting/).
