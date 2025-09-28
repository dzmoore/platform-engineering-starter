#!/usr/bin/env bash

if [[ $- == *i* ]]; then
  alias k="$(which kubectl)"
  source <(kind completion bash)
  source <(kubectl completion bash)
  source <(helm completion bash)
  complete -F __start_kubectl k
  source <(just --completions bash)
  source <(chainsaw completion bash)
fi