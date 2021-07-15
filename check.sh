#!/bin/bash
# URLs for raptoreum explorers. Main and backup one.
URL=( 'https://explorer.raptoreum.com/' 'https://raptor.mopsus.com/' )
URL_ID=0
POSE_SCORE=0
PREV_SCORE=0
LOCAL_HEIGHT=0
# Variables provided by cron job enviroment variable.
# They should also be added into .bashrc for user use.
#NODE_PROTX       -> PROTX of the node in question.
#RAPTOREUM_CLI    -> Path to the raptoreum-cli

# Add your NODE_PROTX here if you forgot or provided wrong hash during node
# installation.
#NODE_PROTX=

function GetNumber () {
  if [[ ${1} =~ '^[+-]?[0-9]+([.][0-9]+)?$' ]]; then
    echo "${1}"
  else
    echo "-1"
  fi
}

function ReadValue () {
  GetNumber "$(cat ${1} 2>/dev/null)"
}

# Allow read anything from CLI with $@ arguments. Timeout after 300s.
function ReadCli () {
  # This should just echo (return) value with standard stdout.
  $(${RAPTOREUM_CLI} "$@") &
  PID=$?
  for i in {0..300}; do
    sleep 1
    if ! ps --pid $PID; then
      # PID ended. Just exit the function.
      return
    fi
  done
  # raptoreum-cli did not return after 300s. kill the PID and exit with -1.
  kill -9 $PID
  echo -1
}

function CheckPoSe () {
  # Check if the Node PoSe score is changing.
  if [[ ! -z ${NODE_PROTX} ]]; then
    POSE_SCORE=$(GetNumber $(curl -s "${URL[$URL_ID]}api/protx?command=info&protxhash=${NODE_PROTX}" | jq -r '.state.PoSePenalty'))
    # Check if the response returned a number or failed.
    if (( POSE_SCORE < 0 )); then
      URL_ID=$(( (URL_ID + 1) % 2 ))
      POSE_SCORE=$(GetNumber $(curl -s "${URL[$URL_ID]}api/protx?command=info&protxhash=${NODE_PROTX}" | jq -r '.state.PoSePenalty'))
    fi
  else
    echo "$(date)  Your NODE_PROTX is empty. Please reinitialize the node again or add it in line #15 of check.sh script."
  fi
  if (( $POSE_SCORE == -1 )); then
    echo "$(date)  Could not get PoSe score for the node. It is possible both explorers are down."
    echo "$(date)  If it happens a lot, please insert your protx hash in line #15 of check.sh script."
  fi
  PREV_SCORE=$(ReadValue "/tmp/pose_score")
  echo ${POSE_SCORE} >/tmp/pose_score

  # Check if we should restart raptoreumd according to the PoSe score.
  if (( POSE_SCORE > 0 )); then
    if (( POSE_SCORE > PREV_SCORE )); then
      killall -9 raptoreumd
      echo "$(date)  Score increased from ${PREV_SCORE} to ${POSE_SCORE} so sent kill signal..."
      echo "1" >/tmp/was_stuck
      # Do not check node height after killing raptoreumd.
      exit
    elif (( POSE_SCORE < PREV_SCORE )); then
      echo "$(date)  Score decreased from ${PREV_SCORE} to ${POSE_SCORE} so wait..."
      rm /tmp/was_stuck 2>/dev/null
    fi
    # POSE_SCORE == PREV_SCORE is gonna force check the node block height.
  fi
}

function CheckBlockHeight () {
  # Check local block height.
  NETWORK_HEIGHT=$(curl -s "${URL[$URL_ID]}api/getblockcount")
  if (( NETWORK_HEIGHT < 0 )); then
    URL_ID=$(( (URL_ID + 1) % 2 ))
    NETWORK_HEIGHT=$(curl -s "${URL[$URL_ID]}api/getblockcount")
  fi
  PREV_HEIGHT=$(ReadValue "/tmp/height")
  LOCAL_HEIGHT=$(GetNumber $(ReadCli getblockcount))
  echo ${LOCAL_HEIGHT} >/tmp/height
  if (( POSE_SCORE == PREV_SCORE )); then
    echo -n "$(date)  Node height (${LOCAL_HEIGHT}/${NETWORK_HEIGHT})."
    # Block height did not change. Is it stuck?. Compare with netowrk block height. Allow some slippage.
    if [[ $((NETWORK_HEIGHT - LOCAL_HEIGHT)) -gt 5 || $NETWORK_HEIGHT == -1 ]]; then
      if (( LOCAL_HEIGHT > PREV_HEIGHT )); then
        # Node is still syncing?
        rm /tmp/was_stuck 2>/dev/null
        echo " Increased from ${PREV_HEIGHT} -> ${LOCAL_HEIGHT} so wait..."
      elif [[ $LOCAL_HEIGHT -gt 0 && $(ReadValue "/tmp/was_stuck") -lt 0 ]]; then
        # Node is behind the network height and it is first attempt at unstucking.
        # If LOCAL_HEIGHT is >0 it means that we were able to read from the cli
        # but the height did not change compared to previous check.
        killall -9 raptoreumd
        echo "1" >/tmp/was_stuck
        echo " Height difference is more than 5 blocks behind the network so sent kill signal..."
      else
        # Node is most probably very stuck and if trying to sync wrong chain branch.
        # This meand simple raptoreumd kill will not help and we need to
        # force unstuck by bootstrapping / resyncing the chain again.
        echo " Node seems to be hardstuck and is trying to sync forked chain so force unstuck..."
        return 1
      fi
    else
      rm /tmp/was_stuck 2>/dev/null
      echo " Daemon seems ok..."
    fi
  fi
  return 0
}

function BootstrapChain () {
  echo "$(date)  Re-Bootstrap the node chain."
  echo "0" >/tmp/height
  echo "0" >/tmp/prev_stuck
  
  BOOTSTRAP_TAR='https://www.dropbox.com/s/y885aysstdmro4n/rtm-bootstrap.tar.gz'
  CONFIG_DIR='~/.raptoreumcore/'
  
  echo "$(date)  Download and prepare rtm-bootstrap."
  rm -rf /tmp/bootstrap 2>/dev/null
  mkdir /tmp/bootstrap 2>/dev/null
  curl -L "$BOOTSTRAP_TAR" | tar xz -C /tmp/bootstrap
  
  echo "$(date)  Kill raptoreumd."
  killall -9 raptoreumd 2>/dev/null

  echo "$(date)  Clean ${CONFIG_DIR}."
  rm -rf ${CONFIG_DIR}/{blocks,chainstate,evodb,llmq}

  # Try to kill raptoreumd again in case it went back up.
  killall -9 raptoreumd 2>/dev/null
  echo "$(date)  Insert Bootstrap data."
  mv tmp/bootstrap/{blocks,chainstate,evodb,llmq} ${CONFIG_DIR}/
  
  rm -rf /tmp/bootstrap 2>/dev/null
}

# This should force unstuck the local node.
function ReconsiderBlock () {
  if [[ $LOCAL_HEIGHT -gt 0 && $LOCAL_HEIGHT -gt $(ReadValue "/tmp/prev_stuck") ]]; then
    # Node is still responsive but is stuck on the wrong branch/fork.
    RECONSIDER=$(( LOCAL_HEIGHT - 5 ))
    HASH=$(ReadCli getclockhash ${RECONSIDER})
    if [[ ${HASH} != "-1" ]]; then
      echo "$(date)  Reconsider chain from 5 blocks before current one ${RECONSIDER}"
      if [[ $(ReadCli reconsiderblock "${HASH}") != "-1" ]]; then
        echo ${RECONSIDER} >/tmp/height
        echo ${LOCAL_HEIGHT} >/tmp/prev_stuck
        return 0
      fi
    fi
  fi
  return 1
}

# Check pose score acording to the explorer data.
CheckPoSe
# PoSe seems fine, did not change or was not able to get the score.
CheckBlockHeight || ReconsiderBlock || BootstrapChain
