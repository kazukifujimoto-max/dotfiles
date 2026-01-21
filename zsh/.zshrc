# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

#Setting zsh-autosuggestions
plugins=( 
    git
    zsh-autosuggestions
)


source $ZSH/oh-my-zsh.sh



##Setting Golang
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
export PATH="/usr/local/opt/mysql-client/bin:$PATH"

##Starship
eval "$(starship init zsh)"


##Setting Alias
alias g='git'
compdef g=git

alias ll='ls -la'
alias cp='cp -i'
alias rm='rm -i'
alias ls='ls --color=auto'
alias src='source ~/.zshrc'
alias path="echo $PATH | tr ':' '\n'"
alias cat='bat'
alias clip='pbcopy'
alias gcc='gcc-14'
alias g++='g++-14'

### Neovim
alias v='nvim'
alias nvcnf='cd ~/.config/nvim'

### terraform
alias tf='terraform'

### docker
alias d='docker'
alias dc='docker compose'

