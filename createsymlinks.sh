#!/bin/bash
# This script creates symlinks from the parent directory to any desired kind
# of files in the directory the present script is located
# Author : Fabien Loudet
# 
#Variables
filetype="pl sh"    #list of extensions for which we want links to be created

# full directory name of the script no matter where it is called from
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# create the symlinks
for file in "$DIR"/*;do
    if [[ -f $file && "$(basename $file)" != "$(basename $0)" ]];then
        for ext in $filetype;do
            if [[ $(basename $file) == *.$ext ]];then
                echo $(basename $file)
                ln -vs $file $(dirname "$DIR")
            fi
        done
    fi
done

