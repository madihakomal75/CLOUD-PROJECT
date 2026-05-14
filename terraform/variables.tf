variable "region" { default = "us-east-1" }
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "db_password" {}
variable "better_auth_secret" {}
variable "encryption_key" {}
variable "google_client_id" {}
variable "google_client_secret" {}
variable "gh_client_id" {}
variable "gh_client_secret" {}
variable "openai_api_key" {}
variable "polar_access_token" {}
variable "lambda_image_tag" {
  type    = string
  default = "9318d858063f205ea8b8139992eb131ff0762d2c"
}