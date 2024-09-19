#!/bin/bash
rm -r outputs/timelapse
mkdir outputs/timelapse
nim c -r -d:release --opt:speed src/reconstruct.nim
