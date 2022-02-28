#!/bin/sh
set -e

STUDENT_IMAGE=${STUDENT_IMAGE:=student-http}
DOCKER=${DOCKER:=docker}

PROJECT_PATH=$(dirname "$0")/..
PROJECT_PATH=$(realpath "${PROJECT_PATH}")

SRC_PATH=${SRC_PATH:=${PROJECT_PATH}/src}
SRV_PATH=${SRV_PATH:=${PROJECT_PATH}/srv}
ETC_PATH=${ETC_PATH:=${PROJECT_PATH}/etc}
mkdir -p ${SRV_PATH}

CREATE_VOLUME=${CREATE_VOLUME:=true}

MYUID=$(id -u)
MYGID=$(id -g)

cd "${PROJECT_PATH}"


docker pull busybox:stable
docker pull nginx:stable
docker pull curlimages/curl:latest


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

copy_to_volume() {
    docker run --rm -v$1:/from:ro -v$2:/to busybox:stable sh -c "rm -rf /to/*;cp -r /from/* /to/;chown -R 101:101 /to/"
}

copy_from_volume() {
    docker run --rm -v$2:/from:ro -v$1:/to busybox:stable sh -c "rm -rf /to/*;cp -r /from/* /to/;chown -R ${MYUID}:${MYGID} /to/"
}

down_local() {
    pkill -x "${SRC_PATH}/http-server" 2>/dev/null || true
}

down_container() {
    ${DOCKER} container rm -f ${STUDENT_IMAGE}-server 2>/dev/null || true
    ${CREATE_VOLUME} && ${DOCKER} volume rm ${STUDENT_IMAGE}-server 2>/dev/null || true
    ${DOCKER} container rm -f ${STUDENT_IMAGE}-nginx 2>/dev/null || true
    ${CREATE_VOLUME} && ${DOCKER} volume rm ${STUDENT_IMAGE}-nginx 2>/dev/null || true
    ${DOCKER} network rm ${STUDENT_IMAGE}-network 2>/dev/null || true

}

down() {
    down_local
    down_container
}

up_local() {
    cd "${SRV_PATH}"
    "${SRC_PATH}/http-server" &
}

up_network() {
    ${DOCKER} network create ${STUDENT_IMAGE}-network
}

up_container_inner() {
    ${CREATE_VOLUME} && ${DOCKER} volume create ${STUDENT_IMAGE}-server
    ${CREATE_VOLUME} && copy_to_volume ${SRV_PATH} ${STUDENT_IMAGE}-server
    ${DOCKER} container run --rm -t --network ${STUDENT_IMAGE}-network -v${STUDENT_IMAGE}-server:/srv${1} --name ${STUDENT_IMAGE}-server ${STUDENT_IMAGE} &
}

up_nginx_inner() {
    ${CREATE_VOLUME} && ${DOCKER} volume create ${STUDENT_IMAGE}-nginx
    ${CREATE_VOLUME} && copy_to_volume ${SRV_PATH} ${STUDENT_IMAGE}-nginx
    ${DOCKER} container run --rm -d --network ${STUDENT_IMAGE}-network -v${STUDENT_IMAGE}-nginx:/srv${1} --name ${STUDENT_IMAGE}-nginx -v${ETC_PATH}:/etc/nginx/conf.d/:ro nginx:stable
}

up_container_rw(){
    up_container_inner
}
up_container_ro(){
    up_container_inner ":ro"
}

up_nginx_rw(){
    up_nginx_inner
}
up_nginx_ro(){
    up_nginx_inner ":ro"
}

run_curl() {
    docker run --rm --network ${STUDENT_IMAGE}-network curlimages/curl:latest ${VERBOSE_ARG} -s -v -H 'Expect:' $@
}

run_nc() {
     docker run --rm --network ${STUDENT_IMAGE}-network busybox:stable nc $@
}


