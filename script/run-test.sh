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

ETC_PATH=${ETC_PATH:=${PROJECT_PATH}/etc}
TESTS_PATH=${PROJECT_PATH}/tests
SRV_PATH=/tmp/${STUDENT_IMAGE}-srv

MYUID=$(id -u)
MYGID=$(id -g)


cd "${PROJECT_PATH}"

prepare_volume() {
    ${DOCKER} volume rm $2 1>/dev/null 2>/dev/null || true
    ${DOCKER} volume create $2 >/dev/null
    ${DOCKER} run --rm -v$TESTS_PATH:/from:ro -v$2:/to busybox:stable sh -c "rm -rf /to/*;cp -r /from/$1 /to/;chown -R 101:101 /to/"
}

diff_volume() {
    ${DOCKER} run --rm -v$2:/vol1:ro -v$3:/vol2:ro busybox:stable diff /vol1/$1 /vol2/$1
}

down_local() {
    pkill -x "${SRC_PATH}/http-server" 2>/dev/null || true
}

down_container() {
    ${DOCKER} container rm -f ${SERVER_NAME} 1>/dev/null 2>/dev/null || true
    ${DOCKER} volume rm ${SERVER_NAME} 1>/dev/null 2>/dev/null || true
    ${DOCKER} container rm -f ${CLIENT_NAME} 1>/dev/null 2>/dev/null || true
    ${DOCKER} volume rm ${CLIENT_NAME} 1>/dev/null 2>/dev/null || true
    ${DOCKER} network rm ${NETWORK_NAME} 1>/dev/null 2>/dev/null || true
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
    ${DOCKER} network create ${NETWORK_NAME} 1>/dev/null 2>/dev/null
}

up_container() {
    ${DOCKER} container run --rm -t --network ${NETWORK_NAME} -v${SERVER_NAME}:/srv --name ${SERVER_NAME} ${STUDENT_IMAGE} http-server &
}

up_nginx() {
    ${DOCKER} container run --rm -d --network ${NETWORK_NAME} -v${SERVER_NAME}:/srv --name ${SERVER_NAME} -v${ETC_PATH}:/etc/nginx/conf.d/:ro nginx:stable 1>/dev/null 2>/dev/null
}

run_curl() {
    ${DOCKER} run --rm --network ${NETWORK_NAME} -v${CLIENT_NAME}:/tmp --name ${CLIENT_NAME} curlimages/curl:latest -s -v -H 'Expect:' $@
}

run_client() {
    ${DOCKER} run --rm --network ${NETWORK_NAME} -v${CLIENT_NAME}:/tmp --name ${CLIENT_NAME} ${STUDENT_IMAGE} http-client $@
}

run_nc() {
    ${DOCKER} run --rm --network ${NETWORK_NAME} -v${CLIENT_NAME}:/tmp --name ${CLIENT_NAME} busybox:stable nc $@
}

case $1 in
get_hello)
    SERVER_DATA="index.html"
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


down
[ ! -z "$SERVER_DATA" ] && prepare_volume "$SERVER_DATA" "$SERVER_NAME"
[ ! -z "$CLIENT_DATA" ] && prepare_volume "$CLIENT_DATA" "$CLIENT_NAME"
up_network
${UP_SERVER}
sleep 5
${RUN_CLI} ${COMMAND}

if [ ! -z "$CHECK" ]; then
    [ ! -z "$SERVER_DATA" ] && diff_volume "$CHECK" "$TESTS_PATH" "$CLIENT_NAME"
    [ ! -z "$CLIENT_DATA" ] && diff_volume "$CHECK" "$TESTS_PATH" "$SERVER_NAME"
fi


echo "Test Passed"
exit 0
