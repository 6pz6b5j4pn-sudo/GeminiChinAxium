# LauraIpsum

This project deploys a small Python AWS Lambda function behind a public
HTTP API. Opening the Terraform `application_url` output displays a greeting
and the Python source used by the Lambda deployment.

## Codespaces setup

The checked-in [devcontainer configuration](.devcontainer/devcontainer.json)
installs Terraform and the AWS CLI. Configure `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY` as Codespaces secrets, then rebuild the Codespace so
the values are available in its terminal. An optional `AWS_SESSION_TOKEN` is
also forwarded for temporary credentials.

The credentials are read from environment variables and are not stored in
Terraform files or source code.

## Deploy

From the Codespaces terminal:

```bash
cd terraform
terraform init
terraform plan
terraform apply
terraform output -raw application_url
```

Open the printed URL in a browser to view the deployed Python code. To remove
the AWS resources when finished:

```bash
terraform destroy
```

Use `-var='aws_region=your-region'` with `plan`, `apply`, and `destroy` if you
want a region other than `us-east-1`.