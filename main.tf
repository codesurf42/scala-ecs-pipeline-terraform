provider "aws" {
    region = "${var.region}"
    access_key = "${var.access_key}"
    secret_key = "${var.secret_key}"
}

resource "aws_iam_role" "codebuild_role" {
    name = "${var.codepipeline_name}_codebuild_role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_ecr_repository" "docker_repository" {
    name = "${lower(var.codepipeline_name)}"
}

resource "aws_iam_role_policy" "codebuild_policy" {

    name = "codebuild-policy"
    role = "${aws_iam_role.codebuild_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [ "*" ],
      "Action": [
        "s3:Get*"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [ "${aws_s3_bucket.scala-build-jar-bucket.arn}", "${aws_s3_bucket.scala-build-jar-bucket.arn}/*" ],
      "Action": [
        "s3:Get*",
        "s3:Put*"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [ "*" ],
      "Action": [ "ecr:GetAuthorizationToken" ]
    },
    {
      "Effect": "Allow",
      "Resource": [ "${aws_ecr_repository.docker_repository.arn}" ],
      "Action": [ "ecr:*" ]
    },
    {
      "Effect": "Allow",
      "Action": [
         "ecs:DeregisterTaskDefinition",
         "ecs:DescribeServices",
         "ecs:DescribeTaskDefinition",
         "ecs:DescribeTasks",
         "ecs:ListTasks",
         "ecs:ListTaskDefinitions",
         "ecs:RegisterTaskDefinition",
         "ecs:StartTask",
         "ecs:StopTask",
         "ecs:UpdateService",
         "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF

}

resource "aws_codebuild_project" "codebuild_docker" {

    name = "${var.codepipeline_name}_codebuild_docker"
    description = "build docker project and push image to ECS"
    build_timeout = "5"

    service_role = "${aws_iam_role.codebuild_role.arn}"

    artifacts {
        type = "CODEPIPELINE"
    }

    environment {
        compute_type = "BUILD_GENERAL1_SMALL"
        image = "aws/codebuild/docker:1.12.1"
        type = "LINUX_CONTAINER"

        environment_variable {
            "name" = "REGION"
            "value" = "${var.region}"
        }

        environment_variable {
            "name" = "ECR_REPO_NAME"
            "value" = "${aws_ecr_repository.docker_repository.name}"
        }

        environment_variable {
            "name" = "ECR_TAG"
            "value" = "latest"
        }

        environment_variable {
            "name" = "ECR_URL"
            "value" = "${aws_ecr_repository.docker_repository.repository_url}"
        }

        environment_variable {
            "name" = "JAR_ARTIFACT_BUCKET"
            "value" = "${aws_s3_bucket.scala-build-jar-bucket.bucket}"
        }

        environment_variable {
            "name" = "JAR_ARTIFACT_KEY"
            "value" = "${lower(var.codepipeline_name)}.jar"
        }
    }

    source {
        type = "CODEPIPELINE"
    }
}

resource "aws_codebuild_project" "codebuild_scala" {

    name = "${var.codepipeline_name}_codebuild_scala"
    description = "build scala project and push jar to S3"
    build_timeout = "5"
    
    service_role = "${aws_iam_role.codebuild_role.arn}"

    artifacts {
        type = "CODEPIPELINE"
    }

    environment {
        compute_type = "BUILD_GENERAL1_SMALL"
        image = "mcarolan/scala-ecs-pipeline-build-scala"
        type = "LINUX_CONTAINER"

        environment_variable {
            "name" = "JAR_ARTIFACT_BUCKET"
            "value" = "${aws_s3_bucket.scala-build-jar-bucket.bucket}"
        }

        environment_variable {
            "name" = "JAR_ARTIFACT_KEY"
            "value" = "${lower(var.codepipeline_name)}.jar"
        }
    }

    source {
        type = "CODEPIPELINE"
    }
}

resource "aws_codebuild_project" "codebuild_deploy" {

    name = "${var.codepipeline_name}_codebuild_deploy"
    description = "trigger deployment on ECS service"
    build_timeout = "10"

    service_role = "${aws_iam_role.codebuild_role.arn}"

    artifacts {
        type = "CODEPIPELINE"
    }

    environment {
        compute_type = "BUILD_GENERAL1_SMALL"
        image = "mcarolan/scala-ecs-pipeline-build-scala"
        type = "LINUX_CONTAINER"

        environment_variable {
            "name" = "ECS_CLUSTER"
            "value" = "${var.ecs_cluster}"
        }

        environment_variable {
            "name" = "ECS_SERVICE"
            "value" = "${var.ecs_service}"
        }

        environment_variable {
            "name" = "ECR_URL"
            "value" = "${aws_ecr_repository.docker_repository.repository_url}"
        }
    }

    source {
        type = "CODEPIPELINE"
    }
}

resource "aws_s3_bucket" "scala-build-jar-bucket" {
    bucket = "${lower(var.codepipeline_name)}-jar-bucket"
    acl = "private"
}

resource "aws_s3_bucket" "codepipeline_bucket" {
    bucket = "${lower(var.codepipeline_name)}-bucket"
    acl = "private"
}

resource "aws_iam_role" "codepipeline_role" {
    name = "${var.codepipeline_name}_role"

    assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "codepipeline.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
    EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
    name = "codepipeline_policy"
    role = "${aws_iam_role.codepipeline_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:Get*",
        "s3:Put*"
      ],
      "Resource": [
        "${aws_s3_bucket.codepipeline_bucket.arn}",
        "${aws_s3_bucket.codepipeline_bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codebuild:BatchGetBuilds",
        "codebuild:StartBuild"
      ],
      "Resource": "*"
    }
  ]
}
EOF

}

resource "aws_codepipeline" "codepipeline" {
    name = "${var.codepipeline_name}"
    role_arn = "${aws_iam_role.codepipeline_role.arn}"

    artifact_store {
        location = "${aws_s3_bucket.codepipeline_bucket.bucket}"
        type = "S3"
    }

    stage {
        name = "downloadSources"

        action {
            name = "scalaSource"
            category = "Source"
            owner = "ThirdParty"
            provider = "GitHub"
            version = "1"
            output_artifacts = [ "scalaSource" ]

            configuration {
                Owner = "${var.service_owner}"
                Repo = "${var.service_repo}"
                Branch = "${var.service_branch}"
                OAuthToken = "${var.github_oauth}"
            }
        }

        action {
           name = "dockerSource"
           category = "Source"
           owner = "ThirdParty"
           provider = "GitHub"
           version = "1"
           output_artifacts = [ "dockerSource" ]

           configuration {
               Owner = "mcarolan"
               Repo = "scala-ecs-pipeline-build-docker"
               Branch = "master"
               OAuthToken = "${var.github_oauth}"
           }
        }

        action {
            name = "deploySource"
            category = "Source"
            owner = "ThirdParty"
            provider = "GitHub"
            version = "1"
            output_artifacts = [ "deploySource" ]

            configuration {
                Owner = "mcarolan"
                Repo = "scala-ecs-pipeline-deploy"
                Branch = "master"
                OAuthToken = "${var.github_oauth}"
            }
        }
    }

    stage {
        name = "buildScala"

        action {
            name = "Build"
            category = "Build"
            owner = "AWS"
            provider = "CodeBuild"
            input_artifacts = [ "scalaSource" ]
            version = "1"

            configuration {
                ProjectName = "${aws_codebuild_project.codebuild_scala.name}"
            }
        }
    }

    stage {
        name = "buildDocker"

        action {
            name = "Build"
            category = "Build"
            owner = "AWS"
            provider = "CodeBuild"
            input_artifacts = [ "dockerSource" ]
            version = "1"

            configuration {
                ProjectName = "${aws_codebuild_project.codebuild_docker.name}"
            }
        }
    }

    stage {
        name = "deploy"

        action {
            name = "Build"
            category = "Build"
            owner = "AWS"
            provider = "CodeBuild"
            input_artifacts = [ "deploySource" ]
            version = "1"

            configuration {
                ProjectName = "${aws_codebuild_project.codebuild_deploy.name}"
            }
        }
    }
}
