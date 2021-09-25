# Hello, World

A small Hello, World! application deployed to ECS.

## Bootstrap

Ensure you have credentials for an IAM user for an AWS account.

Initialize Terraform:

```
terraform init
```

Plan to see the changes:

```
terraform plan
```

When you're ready, bootstrap the infrastructure:

```
terraform apply
```

## Deploy the application

Push to the `main` branch, and the GitHub Action will automatically build the
new container, and update the ECS service.
