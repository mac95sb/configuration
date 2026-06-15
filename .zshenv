if [[ ! -o login ]]; then
  # Environment variables
  . "/nix/store/1rld62d2q0s94z8658f7iv7d8g9sxn4i-hm-session-vars.sh/etc/profile.d/hm-session-vars.sh"

  # Only source this once
  if [[ -z "${__HM_ZSH_SESS_VARS_SOURCED-}" ]]; then
    export __HM_ZSH_SESS_VARS_SOURCED=1
    
  fi
fi
