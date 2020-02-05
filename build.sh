#!/usr/bin/env bash
set -ue

export BINARYBUILDER_AUTOMATIC_APPLE=true

linux="x86_64-linux-gnu"
windows="x86_64-w64-mingw32"
macos="x86_64-apple-darwin14"


# precompile
julia -e "using BinaryBuilder"
mkdir build


rm -rf build products


cuda="julia --project CUDA/build_tarballs.jl"

$cuda --version=v10.2 $linux   --verbose &>build/cuda10.2_linux.log   &
$cuda --version=v10.2 $windows --verbose &>build/cuda10.2_windows.log &

$cuda --version=v10.1 $linux   --verbose &>build/cuda10.1_linux.log   &
$cuda --version=v10.1 $windows --verbose &>build/cuda10.1_windows.log &
$cuda --version=v10.1 $macos   --verbose &>build/cuda10.1_macos.log   &

$cuda --version=v10.0 $linux   --verbose &>build/cuda10.0_linux.log   &
$cuda --version=v10.0 $windows --verbose &>build/cuda10.0_windows.log &
$cuda --version=v10.0 $macos   --verbose &>build/cuda10.0_macos.log   &

$cuda --version=v9.2 $linux    --verbose &>build/cuda9.2_linux.log    &
$cuda --version=v9.2 $windows  --verbose &>build/cuda9.2_windows.log  &
$cuda --version=v9.2 $macos    --verbose &>build/cuda9.2_macos.log    &

$cuda --version=v9.0 $linux    --verbose &>build/cuda9.0_linux.log    &
$cuda --version=v9.0 $windows  --verbose &>build/cuda9.0_windows.log  &
$cuda --version=v9.0 $macos    --verbose &>build/cuda9.0_macos.log    &


cudnn="julia --project CUDNN/build_tarballs.jl"

$cudnn                                   &>build/cudnn.log            &


wait
