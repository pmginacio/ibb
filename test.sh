#!/bin/bash -eu
source ibblib

## START SCRIPT
# declare pattern rule
# ? means dependency
# @ means target
# % is makefile pattern matching syntax
# : means that this argument is ignored when building the command
# which means that the command that will be executed is
#   bcftools index -f "().vcf.gz"
ibrule bcftools index -f "?%.vcf.gz" "@:%.vcf.gz.csi"

# 
declare -a LFILES
for N in $(seq 1 4); do
    LFILES+=("input.chr$N.vcf.gz")
done

mrg() { 
    local N=$1
    shift
    local OUT=$1
    shift
    echo merging $N files ...
    bcftools concat -O z ${@:1:N} >"$OUT"
}
ibrule mrg 2 @input.vcf.gz $(iblist ${LFILES[*]} | ibprf ? | ibflat) $(iblist ${LFILES[*]} | ibprf ?: | ibsuf '.csi' | ibflat)
