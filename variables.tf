variable "access_key" {}
variable "secret_key" {}
variable "region" {
    default = "eu-west-2"
}

variable "codepipeline_name" {}

variable "github_oauth" {}

variable "service_owner" {}
variable "service_repo" {}
variable "service_branch" {}

variable "ecs_cluster" {}
variable "ecs_service" {}
