# scala-ecs-pipeline-terraform

The goal of this project is to build a pipeline that, given:

* An already defined ECS cluster

Will declare:

* An automated build pipeline
* That is capable of performing a green/blue deployments to the ECS cluster

Pre-requisites
--

* A JVM based service with a `buildspec.yml` file that performs the following:

```
version: 0.1
phases:
  build:
    commands:
      - echo Build started on `date`
      - echo Run the test and package the code...
      - sbt assembly
      - aws s3 cp target/scala-2.12/akkaHttp-assembly-0.1-SNAPSHOT.jar s3://$JAR_ARTIFACT_BUCKET/$JAR_ARTIFACT_KEY
  post_build:
    commands:
      - echo Build completed on `date`

```
I.e. it builds a jar containing the service and copies it to s3 at `s3://$JAR_ARTIFACT_BUCKET/$JAR_ARTIFACT_KEY`

* Terraform installed
* An AWS account

Getting started
--

1. Clone the project
```bash
$ git clone git@github.com:mcarolan/scala-ecs-pipeline-terraform.git
```

2. Create a `terraform.tfvars` file:

```hcl-terraform
access_key =          "<<INSERT VALUE>>"
secret_key =          "<<INSERT VALUE>>"
region =              "<<INSERT VALUE>>"
codepipeline_name =   "<<INSERT VALUE>>" 
github_oauth =        "<<INSERT VALUE>>"
service_owner =       "<<INSERT VALUE>>"
service_repo =        "<<INSERT VALUE>>"
service_branch =      "<<INSERT VALUE>>"

ecs_cluster =         "placeholder"
ecs_service =         "placeholder"
```

Key:

| key               | description                                                                              |
|-------------------|------------------------------------------------------------------------------------------|
| access_key        | AWS IAM access key that terraform can use to create resources                            |
| secret_key        | AWS IAM secret key that terraform can use to create resources                            |
| region            | AWS region to create resources in                                                        |
| codepipeline_name | The name of the pipeline you wish to declare (e.g. service name). See restrictions below |
| github_oauth      | Access token code pipeline can use to clone your service. See details below              |
| service_owner     | github account name                                                                      |
| service_repo      | github repo name                                                                         |
| service_branch    | repo branch name                                                                         |
| ecs_cluster       | ECS cluster name, keep as "placeholder" initially                                        |
| ecs_service       | ECS cluster name, keep as "placeholder" initially                                        |

**CodePipeline name restrictions**

This configuration value will be the name of your pipeline, and the prefix of all declared resources.

Some of these resources (e.g. S3 buckets) have global unique name restrictions. If you pick a codepipeline name that causes a uniqueness violation you may see an error like this:

```hcl-terraform
* aws_s3_bucket.codepipeline_bucket: Error creating S3 bucket: BucketAlreadyExists: The requested bucket name is not available. The bucket namespace is shared by all users of the system. Please select a different name and try again.
```
Alter the `codepipeline_name` value, and apply again

**How to obtain a github oauth token**

Go to github.com > settings > personal access tokens > Generate new token > public_repo permissions if repo is public

3. Run `terraform plan` to validate changes without application

4. Run `terraform apply` and cross your fingers!

5. A build will be running in your new CodePipeline. This will fail at the "deploy" stage as you do not have an ECS cluster and service defined yet.

6. Create a new ECS cluster. Pay special attention to:

| key                          | description                                                                                    |
|------------------------------|------------------------------------------------------------------------------------------------|
| name                         | the name of your ECS cluster, this will go in your `terraform.tfvars` file later               |
| instance type                | the specification of the EC2 instances that will form your ECS cluster                         |
| number of instances          | choose at least 2 if you wish to perform blue/green deployments with a service on a fixed port |
| security group/inbound rules | restricts network traffic able to reach the EC2 instances                                      |

If you wish to do a blue/green deployment and have a fixed service port you need > 1 instance

7. Grab the Repository URI of the ECR repository that was declared by heading to: AWS Console > EC2 Container Service > Repositories > `codepipeline_name`

8. Create a new task definition in EC2 Container Service:

| key                     | description                                                                                            |
|-------------------------|--------------------------------------------------------------------------------------------------------|
| name                    | the name of your ECS task definition                                                                   |
| role                    | the role your tasks will run with. this allows you to permit your service to access other AWS services |
| container image         | use the ECR repository URL obtained in the previous step                                               |
| container port mappings | can be used to expose ports your service is listening on                                               |

9. Create a new service in your cluster, using the Task Definition defined in the previous step.
Pay attention to load balancing and number of task instances

10. Update `terraform.tfvars` with the cluster and service names you defined in the previous steps

11. Run `terraform apply` again to apply your changes

12. Re-run your pipeline to deploy your service successfully!