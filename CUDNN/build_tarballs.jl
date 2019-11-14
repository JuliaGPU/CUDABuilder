using BinaryBuilder

name = "CUDNN"

dependencies = []

cudnn_version = v"7.6.5"

script = raw"""
cd ${WORKSPACE}/srcdir

if [[ ${target} == x86_64-linux-gnu ]]; then
    find .
    cd cuda

    # license
    mkdir -p ${prefix}/share/licenses/CUDNN
    mv NVIDIA_SLA_cuDNN_Support.txt ${prefix}/share/licenses/CUDNN/

    # toplevel
    mv lib64 ${prefix}/lib

    # clean up
    rm    ${prefix}/lib/*_static*.a                             # we can't link statically
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    find .
    cd cuda

    # license
    mkdir -p ${prefix}/share/licenses/CUDNN
    mv NVIDIA_SLA_cuDNN_Support.txt ${prefix}/share/licenses/CUDNN/

    # toplevel
    mv bin ${prefix}
    mv lib ${prefix}
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    find .
    cd cuda

    # license
    mkdir -p ${prefix}/share/licenses/CUDNN
    mv NVIDIA_SLA_cuDNN_Support.txt ${prefix}/share/licenses/CUDNN/

    # toplevel
    mv lib ${prefix}

    # clean up
    rm    ${prefix}/lib/*_static*.a                             # we can't link statically
fi
"""

products = [
    LibraryProduct(["libcudnn", "cudnn64_7"], :libcudnn),
]


#
# CUDA 10.1
#

cuda_version = v"10.1"

sources_linux = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.1_20191031/cudnn-10.1-linux-x64-v7.6.5.32.tgz" =>
    "7eaec8039a2c30ab0bc758d303588767693def6bf49b22485a2c00bf2e136cb3"
]
sources_macos = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.1_20191031/cudnn-10.1-osx-x64-v7.6.5.32.tgz" =>
    "8ecce28a5ed388a2b9b2d239e08d7c550f53b79288e6d9e5eb4c152bfc711aff"
]
sources_windows = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.1_20191031/cudnn-10.1-windows10-x64-v7.6.5.32.zip" =>
    "5e4275d738cc3a105cf6558b70b8a2ff514989ca1cd17bc8515086e20561a652"
]

version = VersionNumber(cudnn_version.major, cudnn_version.minor, cudnn_version.patch,
                        ("cuda$(cuda_version.major)$(cuda_version.minor)",))

build_tarballs(ARGS, name, version, sources_linux, script, [Linux(:x86_64)], products, dependencies)
build_tarballs(ARGS, name, version, sources_macos, script, [MacOS(:x86_64)], products, dependencies)
build_tarballs(ARGS, name, version, sources_windows, script, [Windows(:x86_64)], products, dependencies)


#
# CUDA 10.0
#

cuda_version = v"10.0"

sources_linux = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.0_20191031/cudnn-10.0-linux-x64-v7.6.5.32.tgz" =>
    "28355e395f0b2b93ac2c83b61360b35ba6cd0377e44e78be197b6b61b4b492ba"
]
sources_macos = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.0_20191031/cudnn-10.0-osx-x64-v7.6.5.32.tgz" =>
    "6fa0b819374da49102e285ecf7fcb8879df4d0b3cc430cc8b781cdeb41009b47"
]
sources_windows = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/10.0_20191031/cudnn-10.0-windows10-x64-v7.6.5.32.zip" =>
    "2767db23ae2cd869ac008235e2adab81430f951a92a62160884c80ab5902b9e8"
]

version = VersionNumber(cudnn_version.major, cudnn_version.minor, cudnn_version.patch,
                        ("cuda$(cuda_version.major)$(cuda_version.minor)",))

build_tarballs(ARGS, name, version, sources_linux, script, [Linux(:x86_64)], products, dependencies)
build_tarballs(ARGS, name, version, sources_macos, script, [MacOS(:x86_64)], products, dependencies)
build_tarballs(ARGS, name, version, sources_windows, script, [Windows(:x86_64)], products, dependencies)


#
# CUDA 9.2
#

cuda_version = v"9.2"

sources_linux = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/9.2_20191031/cudnn-9.2-linux-x64-v7.6.5.32.tgz" =>
    "a2a2c7a8ba7b16d323b651766ee37dcfdbc2b50d920f73f8fde85005424960e4"
]
sources_windows = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/9.2_20191031/cudnn-9.2-windows10-x64-v7.6.5.32.zip" =>
    "ffa553df2e9af1703bb7786a784356989dac5c415bf5bca73e52b1789ddd4984"
]

version = VersionNumber(cudnn_version.major, cudnn_version.minor, cudnn_version.patch,
                        ("cuda$(cuda_version.major)$(cuda_version.minor)",))

build_tarballs(ARGS, name, version, sources_linux, script, [Linux(:x86_64)], products, dependencies)
build_tarballs(ARGS, name, version, sources_macos, script, [MacOS(:x86_64)], products, dependencies)


#
# CUDA 9.0
#

cuda_version = v"9.0"

sources_linux = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/9.0_20191031/cudnn-9.0-linux-x64-v7.6.5.32.tgz" =>
    "bd0a4c0090d5b02feec3f195738968690cc2470b9bc6026e6fe8ff245cd261c8"
]
sources_windows = [
    "https://developer.nvidia.com/compute/machine-learning/cudnn/secure/7.6.5.32/Production/9.0_20191031/cudnn-9.0-windows10-x64-v7.6.5.32.zip" =>
    "c7401514a6d7d24e8541f88c12e4328f165b5c5afd010ee462d356cac2158268"
]

version = VersionNumber(cudnn_version.major, cudnn_version.minor, cudnn_version.patch,
                        ("cuda$(cuda_version.major)$(cuda_version.minor)",))

build_tarballs(ARGS, name, version, sources_linux, script, [Linux(:x86_64)], products, dependencies)
build_tarballs(ARGS, name, version, sources_macos, script, [MacOS(:x86_64)], products, dependencies)
