#!/bin/bash -eu
source libbash

declare -A IBB_EXPORTED_FUNCTIONS
declare -a IBB_PHONY
IBB_INIT=false

## copied from bash-fun
list() {
  for i in "$@"; do
    echo "$i"
  done
}
unlist() { cat - | xargs; }
##

rep() { sed 's/'$1'/'${2:-}'/g'; }
prf() { while read VAL; do echo $1$VAL; done }
suf() { while read VAL; do echo $VAL$1; done }

irule() {
    local FUN
    local -a LARGS
    local -a LTGTS
    local -a LDEPS
    local HAVE_DEP_PATT=false
    local HAVE_TGT_PATT=false
    
    # export function if not available yet
    FUN=${1}
    if ! ${IBB_EXPORTED_FUNCTIONS[$FUN]:-false}; then
        export -f $FUN
        IBB_EXPORTED_FUNCTIONS[$FUN]=true
        IBB_PHONY+=($FUN)
    fi

    # parse arguments for commands and strip marker characters
    # LARGS=($(list $@ | rep ^@ | rep ^?))
    for ARG in $@; do
        case $ARG in
            \?:*|\@:*)
                # drop argument
                debug "dropping $ARG" >&2
                ;;
            \?*%*)
                # found a pattern dependency
                # replace with make auto variable
                # there can be only one of these
                debug "found pattern dependency $ARG" >&2
                if ! $HAVE_DEP_PATT; then
                    LARGS+=('$<')
                    HAVE_DEP_PATT=true
                else
                    error "found multiple pattern dependencies for rule: $FUN"
                fi
                ;;
            \@*%*)
                # found a pattern target
                # replace with make auto variable
                # there can be only one of these
                debug "found pattern target $ARG" >&2
                if ! $HAVE_TGT_PATT; then
                    LARGS+=('$@')
                    HAVE_TGT_PATT=true
                else
                    error "found multiple pattern targets for rule: $FUN"
                fi
                ;;
            \?* | \@*)
                # strip first char
                debug "found target/dependency $ARG" >&2
                LARGS+=(${ARG:1})
                ;;
            *)
                debug "found silent argument $ARG" >&2
                LARGS+=($ARG)
                ;;
        esac
    done                             
                
    # parse arguments for makefile rule and strip marker characters
    while [[ ! -z ${1:-} ]]; do
        if [[ $1 =~ \@.* ]]; then
            # if @: then strip both, otherwise strip only @
            [[ $1 =~ \@:.* ]] && LTGTS+=(${1:2}) || LTGTS+=(${1:1})
        elif [[ $1 =~ \?.* ]]; then
            # if ?: then strip both, otherwise strip only @
            [[ $1 =~ \?:.* ]] && LDEPS+=(${1:2}) || LDEPS+=(${1:1})
        fi
        shift
    done
    
    # initalize makefile if needed
    if ! $IBB_INIT; then
        echo "SHELL:=/bin/bash" >Makefile
        echo ".ONESHELL:" >>Makefile
        IBB_INIT=true
    fi
    
    # print rules
    echo -e "\n$FUN: ${LTGTS[*]}" >>Makefile
    echo "${LTGTS[*]}: ${LDEPS[*]}" >>Makefile
    echo -e "\t@${LARGS[*]}" >>Makefile
}

ibuild() {
    echo -e "\n.PHONY: ${IBB_PHONY[*]}" >>Makefile
    make $@
}

## START SCRIPT
DEBUG=true
# declare general rule
idx() { echo indexing $1 ...; bcftools index $1; }
irule idx "?%.vcf.gz" "@%.vcf.gz.csi"

# 
declare -a LFILES
for N in $(seq 1 4); do
    LFILES+=("input.chr$N.vcf.gz")
done

mrg() { 
    local OUT=$1
    shift
    echo merging $# files ...
    bcftools concat -O z $@ >"$OUT"
}
irule mrg @input.vcf.gz $(list ${LFILES[*]} | prf ? | unlist) $(list ${LFILES[*]} | prf ?: | suf '.csi' | unlist)

ibuild $@