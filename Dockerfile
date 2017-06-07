#
## Load docker image
#
FROM tatsy/ubuntu-cxx:opencv

#
## Environment variables
#
ENV TERM xterm
ENV BRANCH_NAME development
ENV PULL_REQUEST false
ENV CC gcc
ENV CXX g++
ENV PYTHON_VERSION 3.5

#
## update/upgrade
#
RUN apt-get update -qq
RUN apt-get upgrade -qq

#
## Install Gcovr
#
RUN apt-get -qq install python-pip
RUN pip install gcovr

#
## Install cppcheck, cccc, and doxygen
#
RUN apt-get -qq install cppcheck cccc doxygen

#
## Install Boost
#
RUN wget -q https://dl.bintray.com/boostorg/release/1.64.0/source/boost_1_64_0.tar.gz
RUN tar -zxf boost_1_64_0.tar.gz
RUN \
  cd boost_1_64_0 && \
  ./bootstrap.sh && \
  ./b2 address-model=64 --with-python -j2 install .

#
## Install Python through Anaconda
#
RUN wget -q https://repo.continuum.io/archive/Anaconda3-4.4.0-Linux-x86_64.sh
RUN bash Anaconda3-4.4.0-Linux-x86_64.sh -b -p $HOME/anaconda
ENV PATH "$HOME/anaconda/bin:$PATH"
RUN conda update --yes conda
RUN conda install --yes python=$PYTHON_VERSION setuptools numpy scipy pillow six

#
## Install Google test
#
RUN git clone https://github.com/google/googletest.git
RUN \
  cd googletest && \
  mkdir build && cd build && \
  cmake -D gtest_disable_pthreads=ON .. && \
  make && make install

#
## Build lime
#
RUN git clone --depth 20 -b $BRANCH_NAME https://github.com/tatsy/lime.git
RUN \
  if [ $PULL_REQUEST != "false" ]; then \
    cd lime && \
    git fetch origin +refs/pull/$PULL_REQUEST/merge && \
    git checkout --quiet --force FETCH_HEAD; \
  fi

RUN \
  cd lime && \
  git submodule update --init --recursive

RUN \
  cd lime && \
  cmake \
    -D CMAKE_BUILD_TYPE=Release \
    -D LIME_BUILD_TESTS=ON \
    -D GTEST_ROOT=/usr/local \
    -D PYTHON_INCLUDE_DIR="$HOME/anaconda/include/python$PYTHON_VERSIONm" \
    -D PYTHON_LIBRARY="$HOME/anaconda/lib/libpython$PYTHON_VERSIONm.so" \
    -D LIME_BUILD_PYTHON_MODULE=ON . && \
  cmake --build .

#
## Install pylime
#
RUN \
  cd lime && \
  python setup.py install

#
## # of threads used by OpenMP
#
ENV OMP_NUM_THREADS 4

#
## Define working direcotry
#
WORKDIR /root/lime

#
## Run unit tests
#
RUN lcov --directory . --zerocounters