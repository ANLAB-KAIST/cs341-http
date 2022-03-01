#!/bin/sh
set -e

if [ $# -ne 3 ]; then
    echo "Usage: $0 <test_name> <server> <client>"
    exit 1
fi

STUDENT_IMAGE=${STUDENT_IMAGE:=student-http}
SERVER_NAME=${STUDENT_IMAGE}-server
CLIENT_NAME=${STUDENT_IMAGE}-client
NETWORK_NAME=${STUDENT_IMAGE}-network

DOCKER=${DOCKER:=docker}

PROJECT_PATH=$(dirname "$0")/..
PROJECT_PATH=$(realpath "${PROJECT_PATH}")

SRC_PATH=${SRC_PATH:=${PROJECT_PATH}/src}
ETC_PATH=${ETC_PATH:=${PROJECT_PATH}/etc}
SRV_PATH=/tmp/${STUDENT_IMAGE}-srv

MYUID=$(id -u)
MYGID=$(id -g)

DO_PULL=${DO_PULL:=true}

cd "${PROJECT_PATH}"

build_local() {
    cd "${SRC_PATH}"
    make clean
    make
    cd "${PROJECT_PATH}"
}

build_container() {
    cd "${SRC_PATH}"
    ${DOCKER} build -t ${STUDENT_IMAGE} .
    cd "${PROJECT_PATH}"
}

prepare_volume() {
    ${DOCKER} volume rm $2 2>/dev/null || true
    ${DOCKER} volume create $2
    ${DOCKER} run --rm -v$1:/from:ro -v$2:/to busybox:stable sh -c "rm -rf /to/*;cp -r /from/* /to/;chown -R 101:101 /to/"
}

down_local() {
    pkill -x "${SRC_PATH}/http-server" 2>/dev/null || true
}

down_container() {
    ${DOCKER} container rm -f ${SERVER_NAME} 2>/dev/null || true
    ${DOCKER} volume rm ${SERVER_NAME} 2>/dev/null || true
    ${DOCKER} container rm -f ${CLIENT_NAME} 2>/dev/null || true
    ${DOCKER} volume rm ${CLIENT_NAME} 2>/dev/null || true
    ${DOCKER} network rm ${NETWORK_NAME} 2>/dev/null || true
}

down() {
    down_local
    down_container
}

up_local() {
    mkdir -p "${SRV_PATH}"
    cp ${1}/* ${SRV_PATH}
    cd "${SRV_PATH}"
    "${SRC_PATH}/http-server" &
}

up_network() {
    ${DOCKER} network create ${NETWORK_NAME}
}

up_container() {
    ${DOCKER} container run --rm -t --network ${NETWORK_NAME} -v${SERVER_NAME}:/srv --name ${SERVER_NAME} ${STUDENT_IMAGE} &
}

up_nginx() {
    ${DOCKER} container run --rm -d --network ${NETWORK_NAME} -v${SERVER_NAME}:/srv --name ${SERVER_NAME} -v${ETC_PATH}:/etc/nginx/conf.d/:ro nginx:stable
}

run_curl() {
     ${DOCKER} run --rm --network ${NETWORK_NAME} -v${CLIENT_NAME}:/tmp --name ${CLIENT_NAME} curlimages/curl:latest -s -v -H 'Expect:' $@
}

run_client() {
    ${DOCKER} run --rm --network ${NETWORK_NAME} -v${CLIENT_NAME}:/tmp --name ${CLIENT_NAME} ${STUDENT_IMAGE} $@
}

run_nc() {
    ${DOCKER} run --rm --network ${NETWORK_NAME} -v${CLIENT_NAME}:/tmp --name ${CLIENT_NAME} busybox:stable nc $@
}

test_get_hello() {
    prepare_volume

}

case $1 in
get_hello)
    SERVER_DATA="${PROJECT_PATH}/tests/01"
    COMMAND="-o /tmp/index.html http://${SERVER_NAME}:8080/index.html"
    CHECK="index.html"
    ;;
*)
    echo "Unkown test: $1"
    exit 1
    ;;
esac

case $2 in

nginx)
    UP_SERVER=up_nginx
    ;;

student)
    UP_SERVER=up_container
    ;;
*)
    echo "Unkown server: $2"
    exit 1
    ;;
esac

case $3 in

curl)
    RUN_CLI=run_curl
    ;;

student)
    RUN_CLI=run_client
    ;;
*)
    echo "Unkown client: $3"
    exit 1
    ;;
esac

${DO_PULL} && ${DOCKER} pull busybox:stable
${DO_PULL} && ${DOCKER} pull nginx:stable
${DO_PULL} && ${DOCKER} pull curlimages/curl:latest

build_container
down
[ ! -z "$SERVER_DATA" ] && prepare_volume "$SERVER_DATA" "$SERVER_NAME"
[ ! -z "$CLIENT_DATA" ] && prepare_volume "$CLIENT_DATA" "$CLIENT_NAME"
up_network
${UP_SERVER}
sleep 5
${RUN_CLI} ${COMMAND}
