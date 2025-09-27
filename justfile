build_dir := "build"
package_dir := build_dir / "package"
providers_dir := "crossplane/providers"
timeout := "300s"

GCP_CREDS_SECRET_NAME := "gcp-creds"
GCP_CREDS_SECRET_KEY := "creds"
GCP_CREDS_SECRET_NAMESPACE := "crossplane-system"

default:
  just --list

start-kind:
  #!/usr/bin/env bash
  set -euo pipefail
  ARCH=$(uname -m)
  OS=$(uname -s)

  if ! docker info >/dev/null 2>&1; then
    if [ "${CODESPACES:-}" = "true" ]; then
      echo "Running inside a GitHub Codespace, but docker daemon not available."
      exit 1
    elif [[ "$OS" = "Darwin" || "$OS" = "Linux" ]]; then
      if \
        colima list --profile default --json | 
        yq -e 'select(.status == "Running")' &> /dev/null
      then
        echo 'Colima "default" profile already started'
      else
        echo 'Starting Colima "default" profile with 4 cpu, 6GiB memory, 100GiB disk...'
        colima start --cpu 4 --memory 6 --disk 100
      fi
    else
      echo "Arch: ${ARCH}, OS: ${OS}."
      echo "Docker daemon is not running or not accessible. Start a docker daemon first."
      exit 1
    fi
  fi

  if kind get clusters | grep '^kind$' &> /dev/null ; then
    echo 'kind cluster "kind" already started'
  else
    echo 'Starting kind cluster "kind"...'
    kind create cluster
  fi

stop-kind:
  #!/usr/bin/env bash
  set -euo pipefail
  OS=$(uname -s)

  if kind get clusters | grep '^kind$' &> /dev/null ; then
    echo 'Deleting kind cluster "kind"...'
    kind delete cluster
  else
    echo 'kind cluster "kind" not running.'
  fi

  if [ "${CODESPACES:-}" = "true" ]; then
    echo "Running inside a GitHub Codespace; docker daemon does not need to be stopped."
  elif [[ "$OS" = "Darwin" || "$OS" = "Linux" ]]; then
    if colima list --profile default --json | yq -e &> /dev/null ; then
      echo 'Stopping Colima "default" profile...'
      colima stop
    else
      echo 'Colima "default" profile not running.'
    fi
  fi

install-argocd: start-kind
  #!/usr/bin/env bash
  set -euo pipefail
  if 
  helm list -A --output json | 
    yq -e '
      .[] | 
      select(.name == "argocd" and .namespace == "argocd")
    ' &> /dev/null
  then
    echo 'ArgoCD release already exists'
  else
    helm repo add argo https://argoproj.github.io/argo-helm
    helm upgrade \
      -n argocd \
      --create-namespace \
      --install \
      argocd \
      argo/argo-cd
  fi

install-crossplane: start-kind
  #!/usr/bin/env bash
  set -euo pipefail
  if 
  helm list -A --output json | 
    yq -e '
      .[] | 
      select(.name == "crossplane" and .namespace == "crossplane-system")
    ' &> /dev/null
  then
    echo 'Crossplane release already exists'
    helm repo update
  else
    helm repo add crossplane-stable https://charts.crossplane.io/stable

    helm upgrade crossplane \
      --install \
      --namespace crossplane-system \
      --create-namespace \
      crossplane-stable/crossplane \
      --wait
  fi

apply-providers: install-crossplane
  #!/usr/bin/env bash
  for provider in `ls -1 {{providers_dir}} | grep -v config`; do 
    kubectl apply --filename {{providers_dir}}/$provider;
  done
  kubectl wait --for=condition=healthy provider.pkg.crossplane.io --all --timeout={{timeout}}
  kubectl wait --for=condition=healthy function.pkg.crossplane.io --all --timeout={{timeout}}

apply-package: install-crossplane generate-package
  kubectl apply -f {{package_dir}}/definition.yaml && sleep 1
  kubectl apply -f {{package_dir}}/compositions.yaml

start-control-plane: apply-providers apply-package

make-build-dir:
  mkdir -p {{package_dir}}
  mkdir -p {{package_dir}}/providers

clean: stop-kind
  rm -rf {{build_dir}}

generate-package: make-build-dir
  kcl run kcl/definition.k > {{package_dir}}/definition.yaml
  kcl run kcl/compositions.k > {{package_dir}}/compositions.yaml
  cp -rv crossplane/providers/* {{package_dir}}/providers/

test: start-control-plane
  #!/usr/bin/env bash
  set -euo pipefail
  if [[ -z "${GCP_CREDS:-}" ]]; then
    echo "GCP_CREDS environment variable not set"
    exit 1
  fi
  
  if [[ -z "${GCP_PROJECT_ID:-}" ]]; then
    echo "GCP_PROJECT_ID environment variable not set"
    exit 1
  fi

  kubectl --namespace {{GCP_CREDS_SECRET_NAMESPACE}} \
    create secret generic {{GCP_CREDS_SECRET_NAME}} \
    --from-literal {{GCP_CREDS_SECRET_KEY}}="$GCP_CREDS" \
    --dry-run=client -oyaml | kubectl apply -f -

  GCP_PROJECT_ID=$GCP_PROJECT_ID \
    GCP_CREDS_SECRET_NAME={{GCP_CREDS_SECRET_NAME}} \
    GCP_CREDS_SECRET_NAMESPACE={{GCP_CREDS_SECRET_NAMESPACE}} \
    GCP_CREDS_SECRET_KEY={{GCP_CREDS_SECRET_KEY}} \
    bash tests/test-provider-configs.sh

  chainsaw test --pause-on-failure
