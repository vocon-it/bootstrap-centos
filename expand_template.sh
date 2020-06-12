FILE="${1:-/dev/stdin}"

export CHAIN=CUSTOM_ACCEPT

resolve() {
  echo not implemented yet
}

is_ip() {
  re='^(0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))\.){3}'
    re+='0*(1?[0-9]{1,2}|2([0-4][0-9]|5[0-5]))$'
  if [[ $@ =~ $re ]]; then
    # is an IP address
    return 0
  else
    # is no IP address
    return 1
  fi
}

is_ip_network() {
  IP=$(echo $@ | awk -F '/' '{print $1}')
  NET=$(echo $@ | awk -F '/' '{print $2}') 
  if is_ip $IP && [ $NET -le 32 ] && [ $NET -ge 0 ]; then
    # is an IP network
    return 0
  else
    # is no IP network
    return 1
  fi 
}

INPUT=$1
is_ip $INPUT && echo "$INPUT is an IP address" || echo "$INPUT is no IP address" 
is_ip_network $INPUT && echo "$INPUT is an IP network" || echo "$INPUT is no IP network"
exit 0
---------------

expand_line(){
  LINE=$@
  if echo "$@" | egrep -q "^ACCEPT|^DROP"; then
    JUMP=$(echo $LINE | awk '{print $1}')
    TARGETS=$(echo $LINE | sed "s/^$JUMP //")
    for TARGET in $TARGETS; do
      # TODO: 
      #  here, convert TARGET to IP Network, if needed
      echo "-A $CHAIN -s $TARGET -j $JUMP"
    done
    #echo "$@" | awk -F "^$JUMP " '/^ACCEPT/ {print $2}' | xargs -n 1 echo "-A $CHAIN -s" | sed 's/$/ -j ACCEPT/'
  else
    echo "# NOT_MATCHING"
    #echo "$@"
  fi
}

##########
#  MAIN  #
##########

while read LINE
do
  expand_line $LINE
done < "$FILE"

