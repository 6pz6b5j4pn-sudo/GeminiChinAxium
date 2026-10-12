# LauraIpsum

This project deploys a small Python AWS Lambda function behind a public
HTTP API. Opening the Terraform `application_url` output displays a greeting
and the Python source used by the Lambda deployment.

## Codespaces setup

The checked-in [devcontainer configuration](.devcontainer/devcontainer.json)
installs Terraform, the AWS CLI, and Git LFS. Configure `AWS_ACCESS_KEY_ID` and
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
want a region other than `eu-west-2`.

## GitHub Actions deployment

The [deployment workflow](.github/workflows/deploy.yml) automatically runs
`terraform validate`, `terraform plan`, and `terraform apply` for every push
to `main`. It can also be started manually from the Actions tab.

Before the first run, create a private S3 bucket for Terraform state and add
these secrets to the `copilot` environment under **Settings > Environments**:

- `TF_STATE_BUCKET` — the S3 bucket name
- `AWS_REGION` — optional; defaults to `eu-west-2`
- `AWS_ACCESS_KEY_ID` — the IAM access key ID
- `AWS_SECRET_ACCESS_KEY` — the IAM secret access key

The IAM user associated with these keys must be allowed to read and write the
state bucket and manage the Lambda, API Gateway, and IAM resources declared in
[terraform/main.tf](terraform/main.tf). Enable bucket versioning and block
public access on the state bucket.

If the existing local deployment should be managed by Actions, initialize the
S3 backend and migrate the local state before the first push:

```bash
cd terraform
terraform init \
  -backend-config='bucket=YOUR_TF_STATE_BUCKET' \
  -backend-config='region=eu-west-2' \
  -migrate-state
```

If AWS resources were created before the S3-backed state was configured,
import each existing resource into this state before running the workflow.
The repository also includes a manually triggered **Import existing Terraform
resources** workflow that imports the existing Lambda IAM role:

```bash
terraform import aws_iam_role.lambda laura-ipsum-python-lambda-role
```

Alternatively, run that workflow from the repository's **Actions** tab.
Otherwise, Terraform may attempt to create resources that already exist.