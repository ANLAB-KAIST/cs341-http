#!/bin/sh
set -e

STUDENT_IMAGE=${STUDENT_IMAGE:=student-http}
DOCKER=${DOCKER:=docker}


PROJECT_PATH=$(dirname "$0")/..
PROJECT_PATH=$(realpath "${PROJECT_PATH}")
SRV_PATH=${SRV_PATH:=${PROJECT_PATH}/srv}
mkdir -p ${SRV_PATH}

cd "${PROJECT_PATH}"

build(){
    cd "${PROJECT_PATH}/src"
    make clean
    make
}

build_docker(){
    cd "${PROJECT_PATH}/src"
    ${DOCKER} build -t ${STUDENT_IMAGE} .
}


up_local(){
    cd "${SRV_PATH}"
    "${PROJECT_PATH}/http-server" &
}

up_container(){
    ${DOCKER} network rm ${STUDENT_IMAGE}-network 2> /dev/null || true
    ${DOCKER} container rm -f ${STUDENT_IMAGE}-server 2> /dev/null || true
    ${DOCKER} run --rm -d -v${SRV_PATH}:/srv --name ${STUDENT_IMAGE}-server ${STUDENT_IMAGE}

}
