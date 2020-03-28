export DISPLAY=ylaho3:0
export COLUMNS=143
export LINES=39
export PATH=$PATH:/usr/lib/chromium-browser

if [[ -f /opt/perlbrew/etc/bashrc ]] ; then
  source /opt/perlbrew/etc/bashrc

  ## Variables d'environnement requises
  export PERLBREW_ROOT=/opt/perlbrew
  export PERLBREW_HOME=/tmp/.perlbrew
  source ${PERLBREW_ROOT}/etc/bashrc

  ## Utilisation de la version 5.18.4
  perlbrew use 5.18.4
fi

eval "`dircolors -b`"
alias ls='ls --color=auto'
#alias webpack='/srv/ledgersmb/UI/node_modules/.bin/webpack --colors --display-error-details'

PATH="~/node_modules/.bin:${PATH}"
parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}
# See https://misc.flogisoft.com/bash/tip_colors_and_formatting
PS1="\[\e[0;7;33m\][\!]\[\e[48;5;226;38;5;196m\]\u@\h\[\e[0;1;37m\]{$SHLVL}\[\e[33;1m\]\w\[\e[48;5;4;38;5;226m\]\$(parse_git_branch)\[\e[0m\]\$ "

# enable bash completion in interactive shells
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
