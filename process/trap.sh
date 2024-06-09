#!/bin/bash

term_handler() {
    echo "NO NO"
}

trap 'term_handler' SIGTERM

while true; do
    sleep 1
done
