export HISTFILE="$HOME/.history"
export HISTSIZE=1000000
export SAVEHIST=$HISTSIZE

setopt SHARE_HISTORY        # write+import per command — live sharing across sessions
setopt EXTENDED_HISTORY     # timestamps so cross-session ordering is correct
setopt HIST_IGNORE_ALL_DUPS # de-dupe
setopt HIST_IGNORE_SPACE    # don't record lines starting with a space
setopt HIST_FIND_NO_DUPS    # cleaner history search
