provider "aws" {
    region = "us-east-2"
}
provider "aws" {
    alias = "dr"
    region = "us-west-2"
}