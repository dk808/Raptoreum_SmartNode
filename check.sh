#!/bin/bash
# URLs for raptoreum explorers. Main and backup one.
URL=( 'https://explorer.raptoreum.com/' 'https://raptor.mopsus.com/' )
URL_ID=0

BOOTSTRAP_TAR='https://www.dropbox.com/s/y885aysstdmro4n/rtm-bootstrap.tar.gz'

POSE_SCORE=0
PREV_SCORE=0
LOCAL_HEIGHT=0
# Variables provided by cron job enviroment variable.
# They should also be added into .bashrc for user use.
#RAPTOREUM_CLI    -> Path to the raptoreum-cli
#CONFIG_DIR/HOME  -> Path to "$HOME/.raptoreumcore/"

# Add your NODE_PROTX here if you forgot or provided wrong hash during node
# installation.
#NODE_PROTX=

# Prepare some variables that can be set if the user is runing the script
# manually but are set in cron job enviroment.
if [[ -z $RAPTOREUM_CLI ]]; then
  RAPTOREUM_CLI=$(which raptoreum-cli)
fi

if [[ -z $CONFIG_DIR ]]; then
  if [[ -z $HOME ]]; then
    HOME="/home/$USER/"
  fi
  CONFIG_DIR="$HOME/.raptoreumcore/"
fi

function GetNumber () {
  if [[ ${1} =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]; then
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
  ${RAPTOREUM_CLI} $@ &
  PID=$!
  for i in {0..300}; do
    sleep 1
    if ! ps --pid ${PID} 1>/dev/null; then
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
    POSE_SCORE=$(curl -s "${URL[$URL_ID]}api/protx?command=info&protxhash=${NODE_PROTX}" | jq -r '.state.PoSePenalty')
    # Check if the response returned a number or failed.
    if [[ $(GetNumber $POSE_SCORE) -lt 0 && $POSE_SCORE != "null" ]]; then
      URL_ID=$(( (URL_ID + 1) % 2 ))
      POSE_SCORE=$(curl -s "${URL[$URL_ID]}api/protx?command=info&protxhash=${NODE_PROTX}" | jq -r '.state.PoSePenalty')
    fi
    if [[ $POSE_SCORE == "null" ]]; then
      echo "$(date -u)  Your NODE_PROTX is invalid, please insert your NODE_PROTX hash in line #19 of check.sh script."
    elif (( $(GetNumber $POSE_SCORE) == -1 )); then
      echo "$(date -u)  Could not get PoSe score for the node. It is possible both explorers are down."
    fi
    POSE_SCORE=$(GetNumber $POSE_SCORE)
  else
    echo "$(date -u)  Your NODE_PROTX is empty. Please reinitialize the node again or add it in line #18 of check.sh script."
  fi

  PREV_SCORE=$(ReadValue "/tmp/pose_score")
  echo ${POSE_SCORE} >/tmp/pose_score

  # Check if we should restart raptoreumd according to the PoSe score.
  if (( POSE_SCORE > 0 )); then
    if (( POSE_SCORE > PREV_SCORE )); then
      killall -9 raptoreumd
      echo "$(date -u)  Score increased from ${PREV_SCORE} to ${POSE_SCORE}. Send kill signal..."
      echo "1" >/tmp/was_stuck
      # Do not check node height after killing raptoreumd it is sure to be stuck.
      exit
    elif (( POSE_SCORE < PREV_SCORE )); then
      echo "$(date -u)  Score decreased from ${PREV_SCORE} to ${POSE_SCORE}. Wait..."
      rm /tmp/was_stuck 2>/dev/null
    fi
    # POSE_SCORE == PREV_SCORE is gonna force check the node block height.
  fi
}

function CheckBlockHeight () {
  # Check local block height.
  NETWORK_HEIGHT=$(GetNumber $(curl -s "${URL[$URL_ID]}api/getblockcount"))
  if (( NETWORK_HEIGHT < 0 )); then
    URL_ID=$(( (URL_ID + 1) % 2 ))
    NETWORK_HEIGHT=$(GetNumber $(curl -s "${URL[$URL_ID]}api/getblockcount"))
  fi
  PREV_HEIGHT=$(ReadValue "/tmp/height")
  LOCAL_HEIGHT=$(GetNumber "$(ReadCli getblockcount)")
  echo ${LOCAL_HEIGHT} >/tmp/height
  if [[ $POSE_SCORE -eq $PREV_SCORE || $PREV_SCORE -eq -1 ]]; then
    echo -n "$(date -u)  Node height (${LOCAL_HEIGHT}/${NETWORK_HEIGHT})."
    # Block height did not change. Is it stuck?. Compare with netowrk block height. Allow some slippage.
    if [[ $((NETWORK_HEIGHT - LOCAL_HEIGHT)) -gt 5 || $NETWORK_HEIGHT == -1 ]]; then
      if (( LOCAL_HEIGHT > PREV_HEIGHT )); then
        # Node is still syncing?
        rm /tmp/was_stuck 2>/dev/null
        echo " Increased from ${PREV_HEIGHT} -> ${LOCAL_HEIGHT}. Wait..."
      elif [[ $LOCAL_HEIGHT -gt 0 && $(ReadValue "/tmp/was_stuck") -lt 0 ]]; then
        # Node is behind the network height and it is first attempt at unstucking.
        # If LOCAL_HEIGHT is >0 it means that we were able to read from the cli
        # but the height did not change compared to previous check.
        killall -9 raptoreumd
        echo "1" >/tmp/was_stuck
        echo " Height difference is more than 5 blocks behind the network. Send kill signal..."
      elif [[ $(ReadValue "/tmp/was_stuck") -lt 0 ]]; then
        # Node was not able to respond. It is probably stuck but try to restart
        # it once before trying to bootstrap or restore it.
        killall -9 raptoreumd
        echo "1" >/tmp/was_stuck
        echo " Node was unresponsive for the first time. Send kill signal..."
      else
        # Node is most probably very stuck and if trying to sync wrong chain branch.
        # This meand simple raptoreumd kill will not help and we need to
        # force unstuck by bootstrapping / resyncing the chain again.
        echo " Node seems to be hardstuck and is trying to sync forked chain. Try to force unstuck..."
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
  echo "$(date -u)  Re-Bootstrap the node chain."
  echo "0" >/tmp/height
  echo "0" >/tmp/prev_stuck

  echo "$(date -u)  Download and prepare rtm-bootstrap."
  rm -rf /tmp/bootstrap 2>/dev/null
  mkdir -p /tmp/bootstrap 2>/dev/null
  curl -L "$BOOTSTRAP_TAR" | tar xz -C /tmp/bootstrap/
  
  echo "$(date -u)  Kill raptoreumd."
  killall -9 raptoreumd 2>/dev/null

  echo "$(date -u)  Clean ${CONFIG_DIR}."
  rm -rf ${CONFIG_DIR}/{blocks,chainstate,evodb,llmq}

  # Try to kill raptoreumd again in case it went back up.
  killall -9 raptoreumd 2>/dev/null
  echo "$(date -u)  Insert Bootstrap data."
  mv /tmp/bootstrap/{blocks,chainstate,evodb,llmq} ${CONFIG_DIR}/
  
  rm -rf /tmp/bootstrap 2>/dev/null
  echo "$(date -u)  Bootstrap complete."
}

# This should force unstuck the local node.
function ReconsiderBlock () {
  # If raptoreum-cli is responsive and it is stuck in the different place than before.
  if [[ $LOCAL_HEIGHT -gt 0 && $LOCAL_HEIGHT -gt $(ReadValue "/tmp/prev_stuck") ]]; then
    # Node is still responsive but is stuck on the wrong branch/fork.
    RECONSIDER=$(( LOCAL_HEIGHT - 10 ))
    HASH=$(ReadCli getblockhash ${RECONSIDER})
    if [[ ${HASH} != "-1" ]]; then
      echo "$(date -u)  Reconsider chain from 10 blocks before current one ${RECONSIDER}."
      if [[ -z $(ReadCli reconsiderblock "${HASH}") ]]; then
        echo ${RECONSIDER} >/tmp/height
        echo ${LOCAL_HEIGHT} >/tmp/prev_stuck
        return 0
      fi
    fi
  fi
  # raptoreum-cli is/was unresponsive in at least 1 step
  return 1
}

# Check pose score acording to the explorer data.
CheckPoSe
# PoSe seems fine, did not change or was not able to get the score.
CheckBlockHeight || ReconsiderBlock || BootstrapChain
