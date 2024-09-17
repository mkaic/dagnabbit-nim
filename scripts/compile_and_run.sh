#!/bin/bash
rm -r outputs/timelapse
mkdir outputs/timelapse
nim c -r src/reconstruct.nim
