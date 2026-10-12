terraform {
  backend "s3" {
    key          = "laura-ipsum/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
