FROM nvidia/cuda:11.2.2-devel-ubuntu20.04

# mitsuba part
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y cmake vim git wget 

RUN apt-get install -y \
    build-essential \
    git \
    qt5-default \
    libpng-dev \
    libjpeg-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libeigen3-dev \
    zlib1g-dev \
    clang-9 \
    libc++-9-dev \
    libc++abi-9-dev \
    ninja-build \
    python3-dev \
    python3-distutils \
    python3-setuptools \
    python3-pytest \
    python3-pytest-xdist \
    python3-numpy \
    && apt-get clean \
    && apt-get autoclean \
    && apt-get autoremove


RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    libx11-dev \
    libxxf86vm-dev \
    x11-xserver-utils \
    x11proto-xf86vidmode-dev \
    x11vnc \
    xpra \
    xserver-xorg-video-dummy \
    && apt-get clean \
    && apt-get autoclean \
    && apt-get autoremove

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH

RUN apt-get update --fix-missing && \
    apt-get install -y wget bzip2 ca-certificates libglib2.0-0 libxext6 libsm6 libxrender1 git mercurial subversion && \
    apt-get clean

RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
    /bin/bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    /opt/conda/bin/conda clean -tipsy && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy

RUN conda install python=3.7.3 flask
RUN conda install -c conda-forge opencv
RUN pip install gunicorn

WORKDIR /mitsuba2

ENV CC=clang-9
ENV CXX=clang++-9
ENV CUDACXX=/usr/local/cuda/bin/nvcc
ENV PYTHONPATH=/opt/conda/bin:$PYTHONPATH

RUN git clone --recursive https://github.com/mitsuba-renderer/mitsuba2
RUN cd mitsuba2 \
    && mkdir build \
    && cd build \
    && cmake -GNinja -DPYTHON_EXECUTABLE=/opt/conda/bin/python .. \
    && ninja -j8

RUN mkdir renders
VOLUME [ "/mitsuba2/renders" ]

COPY xorg.conf /etc/X11/xorg.conf
ENV DISPLAY :0

### wrapper to start headless xserver when using mtsimport
# miniconda part


RUN apt-get install -y zip

COPY service.py .
EXPOSE 8000

CMD /bin/bash -c "source /mitsuba2/mitsuba2/setpath.sh && gunicorn -w 4 -b 0.0.0.0:8000 --timeout 3600 service:app"

