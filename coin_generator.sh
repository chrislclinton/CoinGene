#!/bin/bash -e
# This script is a project to clone litecoin into a 
# brand new coin + blockchain.
# The script will perform the following steps:
# 1) Update apt-get and install dependencies lib with ubuntu ready to build and run the new coin daemon
# 2) clone GenesisH0 and mine the genesis blocks of main, test and regtest networks in the container (this may take a lot of time)
# 3) clone litecoin
# 4) replace variables (keys, merkle tree hashes, timestamps..)
# 5) build new coin
# 6) run 4 docker nodes and connect to each other
# 
# By default the script uses the regtest network, which can mine blocks
# instantly. If you wish to switch to the main network, simply change the 
# CHAIN variable below

# change the following variables to match your new coin
COIN_NAME="Birdcoin"
COIN_UNIT="BRD"
# 168 million coins at total (litecoin total supply is 84000000) 84000000 * 2
TOTAL_SUPPLY=168000000
MAINNET_PORT="9332"
TESTNET_PORT="9333"
PHRASE="This is New Coin based on Litecoin"
# First letter of the wallet address. Check https://en.bitcoin.it/wiki/Base58Check_encoding
PUBKEY_CHAR="20"
# number of blocks to wait to be able to spend coinbase UTXO's
COINBASE_MATURITY=100
# leave CHAIN empty for main network, -regtest for regression network and -testnet for test network
CHAIN="-regtest"
# this is the amount of coins to get as a reward of mining the block of height 1. if not set this will default to 50
PREMINED_AMOUNT=100000

# warning: change this to your own pubkey to get the genesis block mining reward
GENESIS_REWARD_PUBKEY=0453CFDD3313102996DE46D0E82C52946B120463DE1F6A1FF4BCFCF2B9A2BB75C5B0B7B84E892A1973BF3A3E19D5A4C4A3FDA4766CB75B6B8837F3BB23D63AAC96

# dont change the following variables unless you know what you are doing
LITECOIN_BRANCH=0.16
GENESISHZERO_REPOS=https://github.com/fgshop/GenesisH0
LITECOIN_REPOS=https://github.com/litecoin-project/litecoin.git
LITECOIN_PUB_KEY=040184710fa689ad5023690c80f3a49c8f13f8d45b8c857fbcbc8bc4a8e4d3eb4b10f4d4604fa08dce601aaf0f470216fe1b51850b4acf21b179c45070ac7b03a9
LITECOIN_MERKLE_HASH=97ddfbbae6be97fd6cdf3e7ca13232a3afff2353e29badfab7f73011edd4ced9
LITECOIN_MAIN_GENESIS_HASH=12a765e31ffd4059bada1e25190f6e98c99d9714d334efa41a195a7e7e04bfe2
LITECOIN_TEST_GENESIS_HASH=4966625a4b2851d9fdee139e56211a0d88575f59ed816ff5e6a63deb4e3e29a0
LITECOIN_REGTEST_GENESIS_HASH=530827f38f93b43ed12af0b3ad25a288dc02ed74d6d7857862df51fc56c416f9
MINIMUM_CHAIN_WORK_MAIN=0x0000000000000000000000000000000000000000000000c1bfe2bbe614f41260
MINIMUM_CHAIN_WORK_TEST=0x000000000000000000000000000000000000000000000000001df7b5aa1700ce
COIN_NAME_LOWER=$(echo $COIN_NAME | tr '[:upper:]' '[:lower:]')
COIN_NAME_UPPER=$(echo $COIN_NAME | tr '[:lower:]' '[:upper:]')
COIN_UNIT_LOWER=$(echo $COIN_UNIT | tr '[:upper:]' '[:lower:]')
DIRNAME=$(dirname $0)
DOCKER_NETWORK="172.18.0"
DOCKER_IMAGE_LABEL="newcoin-env"
OSVERSION="$(uname -s)"


update_dependencies_source()
{
    echo Update apt-get

    # sudo add-apt-repository ppa:bitcoin/bitcoin
    # sudo apt-get update
    # sudo apt-get install libdb4.8-dev libdb4.8++-dev
    # sudo apt-get install libboost-all-dev libzmq3-dev libminiupnpc-dev
    # sudo apt-get install curl git build-essential libtool autotools-dev
    # sudo apt-get install automake pkg-config bsdmainutils python3
    # sudo apt-get install software-properties-commen libssl-dev libevent-dev
    # sudo apt install python-pip
    # pip install scrypt
    # pip install construct

    #git clone https://github.com/litecoin-project/litecoin.git

    echo Finished Update!
}

docker_build_image()
{
    IMAGE=$(docker images -q $DOCKER_IMAGE_LABEL)
    if [ -z $IMAGE ]; then
        echo Building docker image
        if [ ! -f $DOCKER_IMAGE_LABEL/Dockerfile ]; then
            mkdir -p $DOCKER_IMAGE_LABEL
            cat <<EOF > $DOCKER_IMAGE_LABEL/Dockerfile
FROM ubuntu:16.04
RUN echo deb http://ppa.launchpad.net/bitcoin/bitcoin/ubuntu xenial main >> /etc/apt/sources.list
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv D46F45428842CE5E
RUN apt-get update
RUN apt-get -y install ccache git libboost-system1.58.0 libboost-filesystem1.58.0 libboost-program-options1.58.0 libboost-thread1.58.0 libboost-chrono1.58.0 libssl1.0.0 libevent-pthreads-2.0-5 libevent-2.0-5 build-essential libtool autotools-dev automake pkg-config libssl-dev libevent-dev bsdmainutils libboost-system-dev libboost-filesystem-dev libboost-chrono-dev libboost-program-options-dev libboost-test-dev libboost-thread-dev libdb4.8-dev libdb4.8++-dev libminiupnpc-dev libzmq3-dev libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler libqrencode-dev python-pip
RUN pip install construct==2.5.2 scrypt
EOF
        fi 
        docker build --label $DOCKER_IMAGE_LABEL --tag $DOCKER_IMAGE_LABEL $DIRNAME/$DOCKER_IMAGE_LABEL/
    else
        echo Docker image already built
    fi
}

docker_run_genesis()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 $DOCKER_IMAGE_LABEL /bin/bash -c "$1"
}

docker_run()
{
    mkdir -p $DIRNAME/.ccache
    docker run -v $DIRNAME/GenesisH0:/GenesisH0 -v $DIRNAME/.ccache:/root/.ccache -v $DIRNAME/$COIN_NAME_LOWER:/$COIN_NAME_LOWER $DOCKER_IMAGE_LABEL /bin/bash -c "$1"
}

stop_nodes()
{
    echo "Stopping $COIN_NAME_LOWER daemon"
    for id in $(ps -ef | grep $COIN_NAME_LOWER); do
        kill -9 $id
    done
}

remove_nodes()
{
    echo "Removing $COIN_NAME_LOWER nodes"
    for id in $(ps -ef | grep $COIN_NAME_LOWER); do
        kill -9 $id
    done
}

create_network()
{
    echo "Creating $COIN_NAME_LOWER network"
    if ! docker network inspect newcoin &>/dev/null; then
        docker network create --subnet=$DOCKER_NETWORK.0/16 newcoin
    fi
}

remove_network()
{
    echo "Removing $COIN_NAME_LOWER network"
    rm -rf $COIN_NAME_LOWER
}

run_node()
{
    local NODE_NUMBER=$1
    local NODE_COMMAND=$2
    mkdir -p $DIRNAME/miner${NODE_NUMBER}
    if [ ! -f $DIRNAME/miner${NODE_NUMBER}/$COIN_NAME_LOWER.conf ]; then
        cat <<EOF > $DIRNAME/miner${NODE_NUMBER}/$COIN_NAME_LOWER.conf
rpcuser=${COIN_NAME_LOWER}rpc
rpcpassword=$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 32; echo)
EOF
    fi
    cd $DIRNAME/miner${NODE_NUMBER}
    # sh mined${NODE_NUMBER}.sh
}

generate_genesis_block()
{
    if [ ! -d GenesisH0 ]; then
        git clone $GENESISHZERO_REPOS
        cd GenesisH0
    else
        cd GenesisH0
        git pull
    fi

    if [ ! -f ${COIN_NAME}-main.txt ]; then
        echo "Mining genesis block... this procedure can take many hours of cpu work.."
        python $DIRNAME/GenesisH0/genesis.py -a scrypt -z "$PHRASE" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee $DIRNAME/GenesisH0/${COIN_NAME}-main.txt
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-main.txt
    fi

    if [ ! -f ${COIN_NAME}-test.txt ]; then
        echo "Mining genesis block of test network... this procedure can take many hours of cpu work.."
        python $DIRNAME/GenesisH0/genesis.py  -t 1486949366 -a scrypt -z "$PHRASE" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee $DIRNAME/GenesisH0/${COIN_NAME}-test.txt
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-test.txt
    fi

    if [ ! -f ${COIN_NAME}-regtest.txt ]; then
        echo "Mining genesis block of regtest network... this procedure can take many hours of cpu work.."
        python $DIRNAME/GenesisH0/genesis.py -t 1296688602 -b 0x207fffff -n 0 -a scrypt -z "$PHRASE" -p $GENESIS_REWARD_PUBKEY 2>&1 | tee $DIRNAME/GenesisH0/${COIN_NAME}-regtest.txt
    else
        echo "Genesis block already mined.."
        cat ${COIN_NAME}-regtest.txt
    fi

    MAIN_PUB_KEY=$(cat ${COIN_NAME}-main.txt | grep "^pubkey:" | $SED 's/^pubkey: //')
    MERKLE_HASH=$(cat ${COIN_NAME}-main.txt | grep "^merkle hash:" | $SED 's/^merkle hash: //')
    TIMESTAMP=$(cat ${COIN_NAME}-main.txt | grep "^time:" | $SED 's/^time: //')
    BITS=$(cat ${COIN_NAME}-main.txt | grep "^bits:" | $SED 's/^bits: //')

    MAIN_NONCE=$(cat ${COIN_NAME}-main.txt | grep "^nonce:" | $SED 's/^nonce: //')
    TEST_NONCE=$(cat ${COIN_NAME}-test.txt | grep "^nonce:" | $SED 's/^nonce: //')
    REGTEST_NONCE=$(cat ${COIN_NAME}-regtest.txt | grep "^nonce:" | $SED 's/^nonce: //')

    MAIN_GENESIS_HASH=$(cat ${COIN_NAME}-main.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')
    TEST_GENESIS_HASH=$(cat ${COIN_NAME}-test.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')
    REGTEST_GENESIS_HASH=$(cat ${COIN_NAME}-regtest.txt | grep "^genesis hash:" | $SED 's/^genesis hash: //')

    cd ..
}

newcoin_replace_vars()
{
    if [ -d $COIN_NAME_LOWER ]; then
        echo "Warning: $COIN_NAME_LOWER already existing. Not replacing any values"
        return 0
    fi
    if [ ! -d "litecoin-master" ]; then
        # clone litecoin and keep local cache
        git clone -b $LITECOIN_BRANCH $LITECOIN_REPOS litecoin-master
    else
        echo "Updating master branch"
        cd litecoin-master
        git pull
        cd ..
    fi

    git clone -b $LITECOIN_BRANCH litecoin-master $COIN_NAME_LOWER

    cd $COIN_NAME_LOWER

    # first rename all directories
    for i in $(find . -type d | grep -v "^./.git" | grep litecoin); do 
        git mv $i $(echo $i| $SED "s/litecoin/$COIN_NAME_LOWER/")
    done

    # then rename all files
    for i in $(find . -type f | grep -v "^./.git" | grep litecoin); do
        git mv $i $(echo $i| $SED "s/litecoin/$COIN_NAME_LOWER/")
    done

    # now replace all litecoin references to the new coin name
    for i in $(find . -type f | grep -v "^./.git"); do
        $SED -i "s/Litecoin/$COIN_NAME/g" $i
        $SED -i "s/litecoin/$COIN_NAME_LOWER/g" $i
        $SED -i "s/LITECOIN/$COIN_NAME_UPPER/g" $i
        $SED -i "s/LTC/$COIN_UNIT/g" $i
    done

    $SED -i "s/ltc/$COIN_UNIT_LOWER/g" src/chainparams.cpp

    $SED -i "s/84000000/$TOTAL_SUPPLY/" src/amount.h
    $SED -i "s/1,48/1,$PUBKEY_CHAR/" src/chainparams.cpp

    $SED -i "s/1317972665/$TIMESTAMP/" src/chainparams.cpp

    $SED -i "s;NY Times 05/Oct/2011 Steve Jobs, Apple’s Visionary, Dies at 56;$PHRASE;" src/chainparams.cpp

    $SED -i "s/= 9333;/= $MAINNET_PORT;/" src/chainparams.cpp
    $SED -i "s/= 19335;/= $TESTNET_PORT;/" src/chainparams.cpp

    $SED -i "s/$LITECOIN_PUB_KEY/$MAIN_PUB_KEY/" src/chainparams.cpp
    $SED -i "s/$LITECOIN_MERKLE_HASH/$MERKLE_HASH/" src/chainparams.cpp
    $SED -i "s/$LITECOIN_MERKLE_HASH/$MERKLE_HASH/" src/qt/test/rpcnestedtests.cpp

    $SED -i "0,/$LITECOIN_MAIN_GENESIS_HASH/s//$MAIN_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "0,/$LITECOIN_TEST_GENESIS_HASH/s//$TEST_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "0,/$LITECOIN_REGTEST_GENESIS_HASH/s//$REGTEST_GENESIS_HASH/" src/chainparams.cpp

    $SED -i "0,/2084524493/s//$MAIN_NONCE/" src/chainparams.cpp
    $SED -i "0,/293345/s//$TEST_NONCE/" src/chainparams.cpp
    $SED -i "0,/1296688602, 0/s//1296688602, $REGTEST_NONCE/" src/chainparams.cpp
    $SED -i "0,/0x1e0ffff0/s//$BITS/" src/chainparams.cpp

    $SED -i "s,vSeeds.emplace_back,//vSeeds.emplace_back,g" src/chainparams.cpp

    if [ -n "$PREMINED_AMOUNT" ]; then
        $SED -i "s/CAmount nSubsidy = 50 \* COIN;/if \(nHeight == 1\) return COIN \* $PREMINED_AMOUNT;\n    CAmount nSubsidy = 50 \* COIN;/" src/validation.cpp
    fi

    $SED -i "s/COINBASE_MATURITY = 100/COINBASE_MATURITY = $COINBASE_MATURITY/" src/consensus/consensus.h

    # reset minimum chain work to 0
    $SED -i "s/$MINIMUM_CHAIN_WORK_MAIN/0x00/" src/chainparams.cpp
    $SED -i "s/$MINIMUM_CHAIN_WORK_TEST/0x00/" src/chainparams.cpp

    # change bip activation heights
    # bip 16
    $SED -i "s/218579/0/" src/chainparams.cpp
    # bip 34
    $SED -i "s/710000/0/" src/chainparams.cpp
    $SED -i "s/fa09d204a83a768ed5a7c8d441fa62f2043abf420cff1226c7b4329aeb9d51cf/$MAIN_GENESIS_HASH/" src/chainparams.cpp
    # bip 65
    $SED -i "s/918684/0/" src/chainparams.cpp
    # bip 66
    $SED -i "s/811879/0/" src/chainparams.cpp

    # testdummy
    $SED -i "s/1199145601/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    $SED -i "s/1230767999/Consensus::BIP9Deployment::NO_TIMEOUT/g" src/chainparams.cpp

    $SED -i "s/1199145601/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    $SED -i "s/1230767999/Consensus::BIP9Deployment::NO_TIMEOUT/g" src/chainparams.cpp

    # csv
    $SED -i "s/1485561600/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    $SED -i "s/1517356801/Consensus::BIP9Deployment::NO_TIMEOUT/g" src/chainparams.cpp

    $SED -i "s/1483228800/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    $SED -i "s/1517356801/Consensus::BIP9Deployment::NO_TIMEOUT/g" src/chainparams.cpp

    # segwit
    $SED -i "s/1485561600/Consensus::BIP9Deployment::ALWAYS_ACTIVE/g" src/chainparams.cpp
    # timeout of segwit is the same as csv

    # defaultAssumeValid
    $SED -i "s/0x66f49ad85624c33e4fd61aa45c54012509ed4a53308908dd07f56346c7939273/0x$MAIN_GENESIS_HASH/" src/chainparams.cpp
    $SED -i "s/0x1efb29c8187d5a496a33377941d1df415169c3ce5d8c05d055f25b683ec3f9a3/0x$TEST_GENESIS_HASH/" src/chainparams.cpp

    # TODO: fix checkpoints
    cd ..
}

build_new_coin()
{
    # only run autogen.sh/configure if not done previously
    if [ ! -e $COIN_NAME_LOWER/Makefile ]; then
        cd ./$COIN_NAME_LOWER
        echo "autogen.sh"
        bash ./autogen.sh
        echo "configure"
        bash ./configure --disable-tests --disable-bench
    fi
    # always build as the user could have manually changed some files
    echo "make"
    make
    echo "make install"
    make install
}


if [ $DIRNAME =  "." ]; then
    DIRNAME=$PWD
fi

cd $DIRNAME

# sanity check

case $OSVERSION in
    Linux*)
        SED=sed
    ;;
    Darwin*)
        SED=$(which gsed 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "please install gnu-sed with 'brew install gnu-sed'"
            exit 1
        fi
        SED=gsed
    ;;
    *)
        echo "This script only works on Linux and MacOS"
        exit 1
    ;;
esac


# if ! which docker &>/dev/null; then
#     echo Please install docker first
#     exit 1
# fi

# if ! which git &>/dev/null; then
#     echo Please install git first
#     exit 1
# fi

case $1 in
    stop)
        stop_nodes
    ;;
    remove_nodes)
        stop_nodes
        remove_nodes
    ;;
    clean_up)
        stop_nodes
        for i in $(seq 2 5); do
           rm -rf /$COIN_NAME_LOWER /root/.$COIN_NAME_LOWER &>/dev/null
        done
        remove_nodes
        remove_network
        rm -rf $COIN_NAME_LOWER
        if [ "$2" != "keep_genesis_block" ]; then
            rm -f GenesisH0/${COIN_NAME}-*.txt
        fi
        for i in $(seq 2 5); do
           rm -rf miner$i
        done
    ;;
    start)
        # if [ -n "$(docker ps -q -f ancestor=$DOCKER_IMAGE_LABEL)" ]; then
        #     echo "There are nodes running. Please stop them first with: $0 stop"
        #     exit 1
        # fi
        # build_image
        update_dependencies_source
        generate_genesis_block
        newcoin_replace_vars
        build_new_coin
        # reate_network

        $COIN_NAME_LOWER/src/${COIN_NAME_LOWER}-cli $CHAIN getblockchaininfo
        $COIN_NAME_LOWER/src/${COIN_NAME_LOWER}-cli $CHAIN generate 2
    ;;
    *)
        cat <<EOF
Usage: $0 (start|stop|remove_nodes|clean_up)
 - start: bootstrap environment, build and run your new coin
 - stop: simply stop the daemon without removing them
 - remove_nodes: remove the old data. This will stop them first if necessary.
 - clean_up: WARNING: this will stop and remove newcoin and network, source code, genesis block information and nodes data directory. (to start from scratch)
EOF
    ;;
esac
