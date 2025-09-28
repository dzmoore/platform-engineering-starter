#!/usr/bin/env zsh

if [[ $- == *i* ]]; then
  autoload -U compinit && compinit

  alias k="$(which kubectl)"
  source <(kind completion zsh)
  source <(kubectl completion zsh)
  source <(helm completion zsh)
  source <(just --completions zsh)
  source <(chainsaw completion zsh)
  compdef __start_kubectl k
fi