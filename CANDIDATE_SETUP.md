# Candidate setup — install before the interview

Please have the following installed and working on your own machine before
your scheduled interview time. You'll connect directly from your machine;
there is no shared workstation to SSH into.

## Required tools

| Tool | Version |
|---|---|
| kubectl | v1.36.x |
| AWS CLI | v2 (v2.38+) |
| Docker (Engine + Compose) | current stable |
| Terraform | exactly 1.14.0 |
| Helm | v3 (v3.22+) |
| git | any recent (v2.4x+) |
| psql (PostgreSQL client) | v16.x |
| jq | any recent |
| Node.js | v20+ (optional — only needed if you want to run the API outside Docker) |

Optional, not required: `k9s`, `stern`, `argocd` CLI.

## Other requirements

- A bash-capable shell. Native on macOS/Linux. **Windows users need WSL2** —
  the provided helper scripts are bash.
- A stable public IP address for the duration of the interview. Send it to
  us in advance so it can be allowlisted on the cluster beforehand. A VPN or
  mobile hotspot that rotates IPs mid-session will cause `kubectl`/`aws`
  commands to start failing.

## What you'll receive before the interview

- An AWS access key/secret pair for an IAM user scoped to this exercise. It
  works directly for `kubectl`/Docker/ECR (no role assumption needed); a
  second, separate profile is used only for the Terraform exercise.
- An `~/.aws/config`/`~/.aws/credentials` snippet with both profiles set up.
- Access to the GitHub repository.
