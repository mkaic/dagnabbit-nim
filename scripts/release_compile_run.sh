#!/bin/bash
rm -r outputs/timelapse
mkdir outputs/timelapse
nim c -r -d:r src/reconstruct.nim
