#!/bin/bash

# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3709274
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
# Make sure you have a recent version: the code points that Powerline
# uses changed in 2012, and older versions will display incorrectly,
# in confusing ways.
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

# Special Powerline characters

() {
local LC_ALL="" LC_CTYPE="en_US.UTF-8"
# NOTE: This segment separator character is correct.  In 2012, Powerline changed
# the code points they use for their special characters. This is the new code point.
# If this is not working for you, you probably have an old version of the
# Powerline-patched fonts installed. Download and install the new version.
# Do not submit PRs to change this unless you have reviewed the Powerline code point
# history and have new information.
# This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
# what font the user is viewing this source code in. Do not replace the
# escape sequence with a single literal character.
# Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
SEGMENT_SEPARATOR=$'\ue0b0'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
    local bg fg
    [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
    [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
    if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
        echo -n "%{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
    else
        echo -n "%{$bg%}%{$fg%} "
    fi
    CURRENT_BG=$1
    [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
    if [[ -n $CURRENT_BG ]]; then
        echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
    else
        echo -n "%{%k%}"
    fi
    echo -n "%{%f%}"
    CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
    # Check the UID
    if [[ ! -n $COMP ]]; then
        COMP="%m"
    fi

    export PROMP_COLOR='blue'

    if [[ $UID -ne 0 ]]; then # normal user
        if [[ "$USER" != "$DEFAULT_USER" ]]; then
            if [[ -n "$SSH_CLIENT"  ||  -n "$SSH2_CLIENT" ]]; then
                prompt_segment black default "["
                prompt_segment black yellow "$USER@$COMP"
                prompt_segment black default "]"
                export PROMP_COLOR='092'
            else
                prompt_segment black default "["
                prompt_segment black yellow "$USER"
                prompt_segment black default "]"
                export PROMP_COLOR='blue'
            fi
        else
            if [[ -n "$SSH_CLIENT"  ||  -n "$SSH2_CLIENT" ]]; then
                prompt_segment black default "["
                prompt_segment black yellow "$COMP"
                prompt_segment black default "]"
                export PROMP_COLOR='092'
            else
                export PROMP_COLOR='blue'
            fi
        fi
    else # root
        export PROMP_COLOR='red'
        if [[ "$USER" != "$DEFAULT_USER" ]]; then
            if [[ -n "$SSH_CLIENT"  ||  -n "$SSH2_CLIENT" ]]; then
                prompt_segment black default "["
                prompt_segment black yellow "$USER@$COMP"
                prompt_segment black default "]"
            else
                prompt_segment black default "["
                prompt_segment black yellow "$USER"
                #prompt_segment black yellow "%(!.%{%F{red}%}.)$USER"
                prompt_segment black default "]"
            fi
        else
            prompt_segment black default "["
            prompt_segment black yellow "$COMP"
            prompt_segment black default "]"
        fi
    fi
}

# Dir: current working directory
prompt_dir() {
    prompt_segment $PROMP_COLOR black ' %~'
}

# Virtualenv: current working virtualenv
#prompt_virtualenv() {
#    local virtualenv_path="$VIRTUAL_ENV"
#    if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
#        prompt_segment $PROMP_COLOR black "(`basename $virtualenv_path`)"
#    fi
#}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
    local symbols
    symbols=()
    [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
    [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}%⚡"
    [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

    [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

# Git: branch/detached head, dirty status
prompt_git() {
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$' \ue0a0'         # 
  }
  local ref dirty mode repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then

      #   tmp=`git fetch --all`
      dirty=$(parse_git_dirty)
      ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
      if [[ -n $dirty ]]; then
          prompt_segment yellow black
      else
          prompt_segment green black
      fi

      if [[ -e "${repo_path}/BISECT_LOG" ]]; then
          mode=" <B>"
      elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
          mode=" >M<"
      elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
          mode=" >R>"
      fi

      local remote ahead behind git_remote_status git_remote_status_detailed p
      remote=${$(command git rev-parse --verify ${hook_com[branch]}@{upstream} --symbolic-full-name 2>/dev/null)/refs\/remotes\/}

      if [[ -n ${remote} ]]; then
          ahead=$(command git rev-list ${hook_com[branch]}@{upstream}..HEAD 2>/dev/null | wc -l)
          behind=$(command git rev-list HEAD..${hook_com[branch]}@{upstream} 2>/dev/null | wc -l)

          if [[ $ahead -gt 0 ]] && [[ $behind -eq 0 ]]; then
              p=$((ahead))
              if [[ ! $TMUX ]]; then
                  mode=" ${p}%1{⬆︎%} "
              else
                  mode=" ${p}%2{⬆︎%}"
              fi
          elif [[ $behind -gt 0 ]] && [[ $ahead -eq 0 ]]; then
              p=$((behind))
              if [[ ! $TMUX ]]; then
                  mode=" %1{⬇︎%} ${p}"
              else
                  mode=" %2{⬇︎%} ${p}"
              fi
          elif [[ $ahead -gt 0 ]] && [[ $behind -gt 0 ]]; then
              mode=" %1{↕%}"
          fi
      fi

      setopt promptsubst
      autoload -Uz vcs_info

      zstyle ':vcs_info:*' enable git
      zstyle ':vcs_info:*' get-revision true
      zstyle ':vcs_info:*' check-for-changes true
      zstyle ':vcs_info:*' stagedstr '%1{✚%}'
      zstyle ':vcs_info:*' unstagedstr '%1{●%}'
      zstyle ':vcs_info:*' formats ' %u%c'
      zstyle ':vcs_info:*' actionformats ' %u%c'
      vcs_info
      echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
  fi
}


# svn Prompt
#function svn_prompt() {
#    if svn_is_inside; then
#        local ref dirty
#        if svn_parse_dirty; then
#            dirty=$ZSH_THEME_SVN_PROMPT_DIRTY
#        fi
#        echo -n " $(svn_branch_name) $(svn_rev)$dirty"
#    fi
#}
#
#function svn_is_inside() {
#    if $(svn info >/dev/null 2>&1); then
#        return 0
#    fi
#    return 1
#}
#
#function svn_parse_dirty() {
#    if svn_is_inside; then
#        root=`svn info 2> /dev/null | sed -n 's/^Working Copy Root Path: //p'`
#        if $(svn status $root 2> /dev/null | grep -Eq '^\s*[ACDIM!?L]'); then
#            return 0
#        fi
#    fi
#    return 1
#}
#
#function svn_repo_name() {
#    if svn_is_inside; then
#        svn info | sed -n 's/Repository\ Root:\ .*\///p' | read SVN_ROOT
#        svn info | sed -n "s/URL:\ .*$SVN_ROOT\///p"
#    fi
#}
#
#function svn_branch_name() {
#    if svn_is_inside; then
#        svn info 2> /dev/null | \
#            awk -F/ \
#            '/^URL:/ { \
#            for (i=0; i<=NF; i++) { \
#                if ($i == "branches" || $i == "tags" ) { \
#                    print $(i+1); \
#                    break;\
#                }; \
#                if ($i == "trunk") { print $i; break; } \
#                } \
#            }'
#    fi
#}
#
#function svn_rev() {
#    if svn_is_inside; then
#        svn info 2> /dev/null | sed -n 's/Revision:\ //p'
#    fi
#}
#
#
#prompt_svn() {
#
#    local PL_BRANCH_CHAR
#    () {
#    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
#    PL_BRANCH_CHAR=$'\ue0a0'         # 
#}
#if svn_is_inside; then
#    ZSH_THEME_SVN_PROMPT_DIRTY='±'
#    local ref dirty
#    if svn_parse_dirty; then
#        dirty=$ZSH_THEME_SVN_PROMPT_DIRTY
#        prompt_segment yellow black
#    else
#        prompt_segment green black
#    fi
#    echo -n "$PL_BRANCH_CHAR $(svn_branch_name) $(svn_rev)$dirty"
#fi
#
#}


## Main prompt
build_prompt() {
    RETVAL=$?
    prompt_status
    #prompt_virtualenv
    prompt_context
    prompt_dir
    prompt_end
}


r_build_prompt() {
    prompt_git
 #   prompt_svn
}



PROMPT='%{%f%b%k%}$(build_prompt)'

RPS1='$(r_build_prompt) '
