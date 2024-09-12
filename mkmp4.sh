ffmpeg \
-framerate 10 \
-i "outputs/%6d.png" \
-vcodec libx264 \
-crf 18 \
-vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" \
"timelapse.mp4"