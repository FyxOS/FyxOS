# FHS mode "baseline": the shared base, then this mode's build-time activation.
FROM nixos/nix:2.35.2@sha256:7a007c766426c1877758ddc5cb87a965ac131fc78c582ce0083d922d51ae945c
COPY layers.nix base.sh /fhs-src/
RUN sh /fhs-src/base.sh
ENV PATH=/tools/bin:$PATH
COPY activate.sh envfs-shim /fhs-src/
