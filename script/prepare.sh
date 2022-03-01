#!/bin/sh

DOCKER=${DOCKER:=docker}

PROJECT_PATH=$(dirname "$0")/..
PROJECT_PATH=$(realpath "${PROJECT_PATH}")

SRC_PATH=${SRC_PATH:=${PROJECT_PATH}/src}

exit_error() {
    echo "Error: $1"
    exit 1
}


cd "${PROJECT_PATH}/tests" || exit 1

make || exit 1



cd "${PROJECT_PATH}" || exit 1


build_local() {
    cd "${SRC_PATH}" || exit_error ""
    make clean || exit_error "build"
    make || exit_error "build"
    cd "${PROJECT_PATH}" || exit_error ""
}

build_container() {
    cd "${SRC_PATH}" || exit_error ""
    ${DOCKER} build -t ${STUDENT_IMAGE} . || exit_error "container build"
    cd "${PROJECT_PATH}" || exit_error ""
}

DO_PULL=${DO_PULL:=true}

${DO_PULL} && ${DOCKER} pull busybox:stable
${DO_PULL} && ${DOCKER} pull nginx:stable
${DO_PULL} && ${DOCKER} pull curlimages/curl:latest