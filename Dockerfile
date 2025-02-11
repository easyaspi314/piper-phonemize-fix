# Compatible with manylinux_2_36_x86_64/aarch64
FROM debian:bookworm AS build
ARG TARGETARCH
ARG TARGETVARIANT
ARG PYTHON_VERSION
ENV LANG=C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    g++ gcc binutils cmake git patchelf make curl \
    ninja-build

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=/root/.local/bin:$PATH

# build piper-phonemize
WORKDIR /build

COPY . .

RUN cmake -B build -DCMAKE_INSTALL_PREFIX=install -G Ninja
RUN cmake --build build --config Release
RUN cmake --install build

# do a test run
RUN ./build/piper_phonemize --help

WORKDIR /dist
 
# build .tar.gz to keep symlinks
RUN mkdir -p piper_phonemize && \
   cp -dR /build/install/* ./piper_phonemize/ && \
   tar -czf "piper-phonemize_${TARGETARCH}${TARGETVARIANT}.tar.gz" piper_phonemize/

WORKDIR /build

# Build with uv
ENV UV_PYTHON=${PYTHON_VERSION}
RUN uv build
# Repair the wheel. Targets manylinux_2_36_{arch}, but in practice it is actually compatible with manylinux_2_34_{arch}
RUN uvx auditwheel repair dist/*.whl --plat "manylinux_2_36_$(echo ${TARGETARCH} | sed -e 's/amd64/x86_64/' -e 's/arm64/aarch64/' -e 's/arm/armv7l/')" -w /build/wheelhouse
RUN cp /build/wheelhouse/* /dist/
RUN cp dist/*.tar.gz /dist/

# ---------------------

FROM scratch

COPY --from=build /dist/*.tar.gz ./
COPY --from=build /dist/*.whl ./