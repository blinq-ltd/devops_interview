#!/usr/bin/env bash
# Note: deliberately NOT using `set -e`. SSH access (candidate user + admin
# key) is created early and must never be blocked by a later tool-install
# hiccup (e.g. a GitHub release asset renaming). Each step logs its own
# success/failure to /var/log/interview-bootstrap.log instead.
set -uxo pipefail

exec > >(tee -a /var/log/interview-bootstrap.log) 2>&1
echo "=== devops-interview workstation bootstrap started: $(date -u) ==="

export DEBIAN_FRONTEND=noninteractive

step() {
  local desc="$1"
  shift
  echo "--- step: $desc ---"
  if ! "$@"; then
    echo "WARNING: step failed: $desc" | tee -a /var/log/interview-bootstrap-warnings.log
  fi
}

apt-get update -y
apt-get upgrade -y
apt-get install -y \
  unzip curl wget git jq gnupg lsb-release ca-certificates software-properties-common \
  tmux vim nano htop net-tools dnsutils postgresql-client apache2-utils \
  openjdk-17-jre-headless python3-pip

### --- Docker (critical path) ---
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker

### --- candidate user (critical path - do this before any optional tool installs) ---
useradd -m -s /bin/bash candidate
usermod -aG sudo,docker candidate
echo "candidate ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-candidate
chmod 0440 /etc/sudoers.d/90-candidate

install -d -m 0700 -o candidate -g candidate /home/candidate/.ssh
cat > /home/candidate/.ssh/authorized_keys <<'EOF'
${candidate_ssh_public_key}
EOF
chmod 0600 /home/candidate/.ssh/authorized_keys
chown candidate:candidate /home/candidate/.ssh/authorized_keys

### --- admin ssh key(s) (interviewer access, kept off the candidate user; critical path) ---
install -d -m 0700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
cat >> /home/ubuntu/.ssh/authorized_keys <<'EOF'
${admin_ssh_public_keys}
EOF
chmod 0600 /home/ubuntu/.ssh/authorized_keys
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
usermod -aG docker ubuntu

echo "=== critical path (docker, candidate user, ssh access) complete: $(date -u) ==="

### --- everything below is best-effort tooling; failures are logged, not fatal ---

step "aws-cli-v2" bash -c '
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip &&
  unzip -q /tmp/awscliv2.zip -d /tmp &&
  /tmp/aws/install &&
  rm -rf /tmp/awscliv2.zip /tmp/aws
'

step "kubectl" bash -c '
  KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable-${eks_kubernetes_version}.txt)" &&
  curl -fsSL "https://dl.k8s.io/release/$${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl &&
  chmod +x /usr/local/bin/kubectl
'

step "eksctl" bash -c '
  curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /usr/local/bin eksctl
'

step "helm" bash -c '
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
'

step "terraform-${terraform_version}" bash -c '
  curl -fsSL "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_amd64.zip" -o /tmp/terraform.zip &&
  unzip -q -o /tmp/terraform.zip -d /usr/local/bin &&
  rm -f /tmp/terraform.zip
'

step "argocd-cli" bash -c '
  curl -fsSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 &&
  chmod +x /usr/local/bin/argocd
'

step "k9s" bash -c '
  curl -fsSL "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz" | tar xz -C /usr/local/bin k9s
'

# stern release assets embed the version in the filename, so resolve it via the API first.
step "stern" bash -c '
  STERN_TAG="$(curl -fsSL https://api.github.com/repos/stern/stern/releases/latest | grep -m1 "\"tag_name\"" | cut -d\" -f4)" &&
  STERN_VER="$${STERN_TAG#v}" &&
  curl -fsSL "https://github.com/stern/stern/releases/download/$${STERN_TAG}/stern_$${STERN_VER}_linux_amd64.tar.gz" | tar xz -C /usr/local/bin stern
'

### --- Kafka CLI tools (bin/kafka-*.sh) ---
# NOTE: pin this to a version that still exists under
# https://downloads.apache.org/kafka/ at apply time - the mirror only keeps
# recent releases, older ones move to archive.apache.org.
step "kafka-cli-tools" bash -c '
  KAFKA_VERSION="4.4.0"
  SCALA_VERSION="2.13"
  curl -fsSL "https://downloads.apache.org/kafka/$${KAFKA_VERSION}/kafka_$${SCALA_VERSION}-$${KAFKA_VERSION}.tgz" -o /tmp/kafka.tgz &&
  mkdir -p /opt/kafka &&
  tar xzf /tmp/kafka.tgz -C /opt/kafka --strip-components=1 &&
  rm -f /tmp/kafka.tgz &&
  echo "export PATH=\$PATH:/opt/kafka/bin" > /etc/profile.d/kafka.sh &&
  chmod +x /etc/profile.d/kafka.sh
'

step "kcat" bash -c 'apt-get install -y kafkacat || apt-get install -y kcat'

# hey's precompiled binary (hey-release.s3.us-east-2.amazonaws.com) is gone
# (403) and the GitHub releases carry no binary assets (Go-install only, and
# no Go toolchain here). apache2-utils' `ab`, installed above, covers the
# "local load generator" requirement instead.

### --- welcome banner ---
cat > /etc/motd <<'EOF'
=====================================================================
 Blinq DevOps interview workstation
 Installed: docker, aws-cli v2, kubectl (EKS ${eks_kubernetes_version}),
 eksctl, helm, terraform ${terraform_version}, argocd cli, k9s, stern,
 kcat/kafkacat, kafka CLI tools (/opt/kafka/bin), psql, ab (load gen)
 Repo: https://github.com/blinq-ltd/devops_interview
 Check /var/log/interview-bootstrap-warnings.log for any failed steps.
=====================================================================
EOF

touch /var/lib/cloud/instance/interview-bootstrap-complete
echo "=== devops-interview workstation bootstrap finished: $(date -u) ==="
