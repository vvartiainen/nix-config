#compdef claude

typeset -gA _claude_cmd_names _claude_cmd_specs _claude_opt_specs

_claude_parse_help() {
  local key=${(j: :)@}
  (( ${+_claude_cmd_specs[$key]} )) && return

  local line section sig desc name flag
  local -a names cmd_specs opt_specs
  for line in ${(f)"$(_call_program help claude "$@" --help 2>/dev/null </dev/null)"}; do
    case $line in
      Commands:*) section=cmds; continue ;;
      Options:*) section=opts; continue ;;
      [^\ ]*) section=; continue ;;
    esac
    sig=${${line#  }%%  *}
    desc=${${line##*  }//:/\\:}
    [[ $desc == $sig ]] && desc=
    if [[ $section == cmds && $line == '  '[a-z]* ]]; then
      for name in ${(s:|:)${sig%% *}}; do
        names+=$name
        cmd_specs+="$name:$desc"
      done
    elif [[ $section == opts && $line == '  '-* ]]; then
      for flag in ${(s:, :)sig}; do
        opt_specs+="${flag%% *}:$desc"
      done
    fi
  done
  _claude_cmd_names[$key]=${(j: :)names}
  _claude_cmd_specs[$key]=${(pj:\0:)cmd_specs}
  _claude_opt_specs[$key]=${(pj:\0:)opt_specs}
}

_claude() {
  local -a cmd_path known specs
  local word
  for word in ${words[2,CURRENT-1]}; do
    _claude_parse_help $cmd_path
    known=(${=_claude_cmd_names[${(j: :)cmd_path}]})
    (( ${known[(Ie)$word]} )) && cmd_path+=$word
  done
  _claude_parse_help $cmd_path

  local key=${(j: :)cmd_path}
  if [[ $PREFIX == -* ]]; then
    specs=(${(ps:\0:)_claude_opt_specs[$key]})
    _describe -t options option specs
  elif [[ -n ${_claude_cmd_specs[$key]} ]]; then
    specs=(${(ps:\0:)_claude_cmd_specs[$key]})
    _describe -t commands command specs
  else
    _files
  fi
}

_claude "$@"
