#!/bin/bash

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
set -o pipefail

execs="start delete state serial_start create pause mount container container-wrapper"

kernel_path=""
busybox_path=""
params=""

while (( "$#" )); do
    case "$1" in
        --kernel-path)
            kernel_path=$2
            shift
            shift
            ;;
        --busybox-path)
            busybox_path=$2
            shift
            shift
            ;;
        -*|--*=)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            params="$1"
            shift
            ;;
    esac
done
set -- "${params[@]}"

# Clean the repo, but save the vendor area
if [ "x${1:-}" != "x" ] && [ "clean" == "$1" ]; then
    echo "cleaning project"
    rm -rf kernel/out
    rm -rf kernel/build
    rm -rf initrd/out
    rm -rf target
    cd sendfd
    make clean
    cd -

    exit 0
fi

if [ -z "$kernel_path" ] || [ -z "$busybox_path" ]; then
    echo "Expected kernel and busybox paths." >&2
    exit 1
fi

# Support cross-compiling via ARCH variable
if [[ -z "$ARCH" ]]
then
    ARCH=`uname -p`
fi
if [[ $ARCH = "x86_64" ]]
then
    export ARCH="x86"
elif [[ $ARCH = "aarch64" ]]
then
    export ARCH="arm64"
elif [[ $ARCH = "arm*" ]]
then
    export ARCH="arm"
else
    echo Architecture not supported
    exit 1
fi

mkdir -p target/usr/share/runX
for i in $execs; do
    cp files/$i target/usr/share/runX
done

mkdir -p target/etc
cp config/runx.conf target/etc

cd sendfd
make
cd ..
cp sendfd/sendfd target/usr/share/runX/

mkdir -p target/usr/sbin
cp runX target/usr/sbin

# Build the kernel and initrd
if test \! -f target/usr/share/runX/kernel
then
    kernel/make-kernel "$kernel_path"
    cp kernel/out/kernel target/usr/share/runX
fi
if test \! -f target/usr/share/runX/initrd
then
    initrd/make-initrd "$busybox_path"
    cp initrd/out/initrd target/usr/share/runX
fi
