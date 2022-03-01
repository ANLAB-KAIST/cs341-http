#!/bin/sh

PROJECT_PATH=$(dirname "$0")
PROJECT_PATH=$(realpath "${PROJECT_PATH}")
"${PROJECT_PATH}/script/prepare.sh"
"${PROJECT_PATH}/script/run-test.sh" get_hello nginx student
