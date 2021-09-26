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

## Monitoring

There are two alarms automatically configured:

1. 5xx errors: We care mostly about the error rate being returned by the
   application. This is the alarm that has a direct impact on customers,
   and should be treated as severe. It normally suggests the application
   is misbehaving, or at capacity.

2. Healthy hosts in the load balancer: If we don't have any healthy
   hosts, then we'll definitely have issues. In a containerised
   environment this may denote that the service is unable to actually
   start, or the containers are constantly crashing. It can be a little
   unreliable, as sometimes containers are able to start, and then crash
   a minute later, meaning the metric stays above 1; but in any case,
   our 5xx alert should notify us there's an issue, but this alert
   should guide us to where to look.

