#!/bin/bash
rm outputs/*.png
rm latest.png
nim c -r test.nim
