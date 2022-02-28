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

MYUID=$(id -u)
MYGID=$(id -g)

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

down_local() {
    pkill -x "${SRC_PATH}/http-server" 2>/dev/null || true
}

down_container() {
    ${DOCKER} container rm -f ${STUDENT_IMAGE}-server 2>/dev/null || true
    ${DOCKER} container rm -f ${STUDENT_IMAGE}-nginx 2>/dev/null || true
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

up_container() {
    ${DOCKER} container run --rm -t --network ${STUDENT_IMAGE}-network -v${SRV_PATH}:/srv --name ${STUDENT_IMAGE}-server ${STUDENT_IMAGE} &
}

up_nginx() {
    ${DOCKER} container run --rm -t --network ${STUDENT_IMAGE}-network -v${SRV_PATH}:/srv --name ${STUDENT_IMAGE}-nginx -v${ETC_PATH}:/config/nginx/site-confs -e PUID=${MYUID} -e PGID=${MYGID} linuxserver/nginx:latest &
}

