#!/usr/bin/env bash

# Copyright 2018 The Knative Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

export GO111MODULE=on
# If we run with -mod=vendor here, then generate-groups.sh looks for vendor files in the wrong place.
export GOFLAGS=-mod=

if [ -z "${GOPATH:-}" ]; then
  export GOPATH=$(go env GOPATH)
fi

source $(dirname $0)/../vendor/knative.dev/hack/library.sh

CODEGEN_PKG=${CODEGEN_PKG:-$(cd ${REPO_ROOT_DIR}; ls -d -1 $(dirname $0)/../vendor/k8s.io/code-generator 2>/dev/null || echo ../../../k8s.io/code-generator)}

KNATIVE_CODEGEN_PKG=${KNATIVE_CODEGEN_PKG:-$(cd ${REPO_ROOT_DIR}; ls -d -1 $(dirname $0)/../vendor/knative.dev/pkg 2>/dev/null || echo ../pkg)}

chmod +x ${CODEGEN_PKG}/generate-groups.sh
chmod +x ${KNATIVE_CODEGEN_PKG}/hack/generate-knative.sh

# Sources and Bindings

# generate the code with:
# --output-base    because this script should also be able to run inside the vendor dir of
#                  k8s.io/kubernetes. The output-base is needed for the generators to output into the vendor dir
#                  instead of the $GOPATH directly. For normal projects this can be dropped.
${CODEGEN_PKG}/generate-groups.sh "deepcopy,client,informer,lister" \
  "knative.dev/eventing-gitlab/pkg/client" "knative.dev/eventing-gitlab/pkg/apis" \
  "sources:v1alpha1 bindings:v1alpha1" \
  --go-header-file ${REPO_ROOT_DIR}/hack/boilerplate.go.txt

# Knative Injection
${KNATIVE_CODEGEN_PKG}/hack/generate-knative.sh "injection" \
  "knative.dev/eventing-gitlab/pkg/client" "knative.dev/eventing-gitlab/pkg/apis" \
  "sources:v1alpha1 bindings:v1alpha1" \
  --go-header-file ${REPO_ROOT_DIR}/hack/boilerplate.go.txt

# Depends on generate-groups.sh to install bin/deepcopy-gen
${GOPATH}/bin/deepcopy-gen \
  -O zz_generated.deepcopy \
  --go-header-file ${REPO_ROOT_DIR}/hack/boilerplate.go.txt \
  -i knative.dev/eventing-gitlab/pkg/apis

# Make sure our dependencies are up-to-date
${REPO_ROOT_DIR}/hack/update-deps.sh
