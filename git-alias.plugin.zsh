alias ginit='git init'
alias gcreate='ginit && gh repo create --private'
alias gcreatepub='ginit && gh repo create --public'

alias gs='git status -sb'
alias gdc='git diff --cached'
alias gcommitgrep='git log --grep '
alias gpickaxe='git log -p -S '
alias gf='git fetch --prune'
function prune_gone_branches {
    for branch in $(git for-each-ref --format '%(refname) %(upstream:track)' refs/heads | awk '$2 == "[gone]" {sub("refs/heads/", "", $1); print $1}')
    do
        git branch -D "$branch"
    done
}

# Git fetch prune local branches that are deleted on remote
alias gfprunelocal="gf && prune_gone_branches"
alias gcommit='git commit'
alias gfixup='gf && gcommit --fixup=HEAD'
alias gca='git commit -a'
alias gcap='gca && gpush'
alias grebase='git rebase '
alias grebasec='grebase --continue '
alias grebasea='grebase --abort '
alias gnb='gcheckout -b '
alias gpush='git push '
alias greset='git reset '
alias gpull='git pull --rebase'
alias gclone='git clone '
alias gstash='git stash '
alias gadd='git add '
alias gadda='git add .'
alias gpushtags='git push origin --tags'
alias gremotes='git remote -v'
alias gremote='git remote'
alias gremotea='git remote add'
alias gorigin='git config --get remote.origin.url'

alias grel='gh release'
alias grelc='grel create'

alias gwip='gca -m WIP && gpush'
alias gupd='gca -m UPD && gpush'
alias gdots='gca -m "chore: Update dotfiles" && git push'
alias gnotes='gca -m "docs: Update notes" && gpush'

function gdom {
  query=$1
  default_remote_branch=$(git remote show origin | grep "HEAD branch" | sed "s/.*: //")
  if [[ "$query" == "--stat" ]]; then
    git diff origin/$default_remote_branch --stat
    return
  fi

  file=$(
    git diff origin/"$default_remote_branch" --stat --color=always | \
    fzf --query=$query --ansi --prompt "GitFiles?> " \
      --preview="git diff origin/$default_remote_branch --color=always -- {1}" | \
    awk '{print $1}'
  )
  [ ! -z $file ] && git diff origin/$default_remote_branch $file
}

function grom {
  default_remote_branch=$(git remote show origin | grep "HEAD branch" | sed "s/.*: //")
  git fetch
  git rebase origin/"$default_remote_branch"
}

gdob () { git diff origin/$(_local_branch) $@ }
compdef _git-diff gdob

function pr {
  local repo_origin=`gorigin`;

  default_remote_branch=$(git remote show origin | grep "HEAD branch" | sed "s/.*: //")

  if [[ $repo_origin =~ "git@gitlab.com" ]]
  then
    grom && gpushbranch && lab merge-request -s -d $@
  else
    grom && gpushbranch && gh pr create --fill --base $default_remote_branch $@
  fi
}

alias pr=pr

alias grom=grom

function gshow {
  if [ -n "$1" ]; then
    git show "$1"
  else
    local commit=`fcommit`
    if [[ -n $commit ]]; then
      cmd="git show $@ $commit"
      print -s $cmd
      eval $cmd
    fi
  fi
}


gcheckoutbranch() {
  local branch_name=$(_fzf_git_branches)
  if [[ $branch_name =~ ^origin ]]; then
    branch_name=$(echo $branch_name | sed -e 's/^origin\///')
  fi
  if [[ -n $branch_name ]]; then
    cmd="git checkout $@ $branch_name"
    print -s $cmd
    eval $cmd
  fi
}

gresetbranch() {
  local branch_name=$(_fzf_git_branches)
  if [[ -n $branch_name ]]; then
    cmd="git reset $@ $branch_name"
    print -s $cmd
    eval $cmd
  fi
}
compdef _git-reset gresetbranch

alias gcb=gcheckoutbranch
compdef _git-checkout gcheckoutbranch

gresetfilefromhead() {
  file=$(git diff-tree --no-commit-id --name-only -r HEAD | fzf)
  if [[ -n $file ]]; then
    git reset --soft HEAD^
    git reset HEAD $file
    cmd="git reset HEAD $file"
    git commit -c ORIG_HEAD --amend
  fi
}

grbc() {
  local commit=`fcommit`
  [[ -n $commit ]] && print -z git rebase -i $@ $commit
}

grbb() {
  branch=$(_git_fzf_branches)
  [[ -n $branch ]] && print -z git rebase $@ origin/$branch
}

compdef _git-rebase grbc grbb

# TODO: FZF preview window commit message
goneline() {
  git log --pretty=oneline --decorate=short | \
    fzf | \
    awk '{print $1}' | \
    tr -d '\n' | \
    xclip -selection clipboard
}

gresetcommit() {
  commit=`fcommit`
  [[ -n $commit ]] && print -z git reset $@ $commit
}

gresetbranch() {
  branch=$(_git_fzf_branches)
  [[ -n $branch ]] && print -z git reset $@ "$branch"
}

compdef _git-reset gresetcommit gresetbranch

gformatpatch() {
  commit=`fcommit`
  [[ -n $commit ]] && print -z git format-patch $@ $commit
}

grevert() {
  commit=`fcommit`
  [[ -n $commit ]] && print -z git revert $@ $commit
}

compdef _git-format-patch gformatpatch

gsha1() {
  print -z `fcommit`
}

_local_branch() {
  git symbolic-ref --short HEAD
}

_remote_branch() {
  remote=$(git remote)
  if [ $? != 0 ]; then
    return 1 # Returning $? will return the output of the if test.
  fi

  branch=$(_local_branch)

  if [ $(echo $remote | wc -l) = 1  ]; then
    echo "$remote $branch"
  else
    # If we have multiple remotes, default to origin
    echo origin $branch
  fi
}

function delete_dead_branches {
  dead_branches=$(git branch --merged=master | egrep --invert-match '(master|production)')
  echo $dead_branches | while read branch; do
    # If branch name does not contain just whitespace
    if [[ $branch = *[![:space:]]* ]]; then
      git branch -d $branch
    fi
  done
}

gpullbranch() {
  branch=$(_local_branch)
  if [ $? = 0 ]; then
    git fetch --prune
    git pull $@ origin $branch
    delete_dead_branches
  fi
}
compdef _git-pull gpullbranch

gpushbranch() {
  branch=$(_remote_branch)
  [ $? = 0 ] && eval git push --set-upstream $@ $branch
}
compdef _git-push gpushbranch

alias gplb=gpullbranch
alias gpsb=gpushbranch

gcherry() {
  current_branch=$(_local_branch)
  unmerged_branch=$(git branch --no-merged $current_branch | cut -c 3- | fzf)
  commits=$(git rev-list $unmerged_branch --not $current_branch --no-merges --pretty=oneline --abbrev-commit | fzf -m)
  num_commits=$(echo $commits | wc -l)

  if [[ $num_commits -gt '2' ]]; then
    echo "Select 1 to 2 commits, starting at the oldest commit"
  elif [[ $num_commits -eq '1' ]]; then
    commit=$(echo $commits | awk '{print $1}')
    print -z git cherry-pick "$commit"
  elif [[ $num_commits -eq '2' ]]; then
    first=$(echo $commits | awk '{if (NR==1) print $1}')
    second=$(echo $commits | awk '{if (NR==2) print $1}')
    cmd="git cherry-pick \"$first^..$second\""
    print -s $cmd
    eval "$cmd"
  fi
}

function gcherrynewbranch {
  python3 -c "import git_helpers; git_helpers.git_cherry_pick_new_branch()"
}

function gcherrypr {
  python3 -c "import git_helpers; git_helpers.git_cherry_pick_new_branch()"
  gpushbranch
  gh pr create --fill
}

function gdelbranch {
  branches=$(_git_fzf_branches)
  if [ -z "$branches" ]; then
    echo Provide a branch name
    return
  fi
  while read -r branch; do
    git branch -d "$branch"
    git push origin --delete "$branch"
  done <<< $branches
}
compdef _git-branch gdelbranch

function gdeltag {
  tag_name=$1
  if [ -z "$tag_name" ]; then
    echo Provide a tag name
    return
  fi
  git tag -d "$tag_name"
  git push origin :"$tag_name"
}
compdef _git-branch gdeltag
