# syntax=docker/dockerfile:1

# Overlay recipe for the devin-in-a-box mixin: one environment variable and
# one file outside /home.
#
# A mixin's ENV merges into the composed image, so DEVIN_MODEL reaches the
# devin kit's entrypoint, `sbx exec` and every process the agent starts. The
# first kit to set a variable owns it; the devin kit does not set
# DEVIN_MODEL, so the merge cannot conflict. Devin CLI reads DEVIN_MODEL as
# the default for --model; an unknown model name is an error that lists the
# models the account can use.
#
# config.json lands under /usr/local/share, not in ~/.config/devin: two kits
# that ship the same path fail when sbx composes them, and the devin kit's
# image already holds ~/.config/devin/config.json. The descriptor's install
# hook copies it into place.
#
# No --chmod on the COPY: BuildKit applies that mode to the parent directories
# it creates as well, and a mixin's directory entries replace the base's, so
# a 0644 /usr would lock the agent out of every program. A plain COPY keeps
# the file's own mode (0644 in git) and creates the parents root-owned 0755,
# which is what /usr is on any base.
FROM scratch
ENV DEVIN_MODEL=swe-1.6
COPY config.json /usr/local/share/devin-in-a-box/config.json
