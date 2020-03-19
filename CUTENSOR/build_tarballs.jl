using BinaryBuilder

name = "CUTENSOR"
tag = v"0.3.0"

dependencies = []

output = Dict()

cutensor_version = v"1.0.1"

products = [
    LibraryProduct(["libcutensor"], :libcutensor),
]

sources_linux = [
    "https://developer.download.nvidia.com/assets/gameworks/downloads/secure/cuTensor/libcutensor-linux-x86_64-1.0.1.tar.gz" =>
    "ca6122b3f15511cd33a5eb7f911cff1553def1d3ff0b9270e62ef08f1a94f2aa"
]


#
# CUDA 10.2
#

cuda_version = v"10.2"
output[cuda_version] = Dict()

script = raw"""
cd ${WORKSPACE}/srcdir

if [[ ${target} == x86_64-linux-gnu ]]; then
    cd libcutensor
    find .

    # prepare
    mkdir ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUTENSOR
    mv license.pdf ${prefix}/share/licenses/CUTENSOR/

    # CUTENSOR Library
    mv lib/10.2/libcutensor.so* ${prefix}/lib
    mv include/* ${prefix}/include
fi
"""

merge!(output[cuda_version], build_tarballs(ARGS, name, cutensor_version, sources_linux, script, [Linux(:x86_64)], products, dependencies))


#
# CUDA 10.1
#

cuda_version = v"10.1"
output[cuda_version] = Dict()

script = raw"""
cd ${WORKSPACE}/srcdir

if [[ ${target} == x86_64-linux-gnu ]]; then
    cd libcutensor
    find .

    # prepare
    mkdir ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUTENSOR
    mv license.pdf ${prefix}/share/licenses/CUTENSOR/

    # CUTENSOR Library
    mv lib/10.1/libcutensor.so* ${prefix}/lib
    mv include/* ${prefix}/include
fi
"""

merge!(output[cuda_version], build_tarballs(ARGS, name, cutensor_version, sources_linux, script, [Linux(:x86_64)], products, dependencies))


#
# Generate artifact
#

using Pkg
using Pkg.Artifacts

bin_path = "https://github.com/JuliaGPU/CUDABuilder/releases/download/v$(tag)"
artifacts_toml = joinpath(@__DIR__, "Artifacts.toml")

for cuda_version in keys(output)
    src_name = "CUTENSOR+CUDA$(cuda_version.major).$(cuda_version.minor)"

    for platform in keys(output[cuda_version])
        tarball_name, tarball_hash, git_hash, products_info = output[cuda_version][platform]

        download_info = Tuple[
            (joinpath(bin_path, basename(tarball_name)), tarball_hash),
        ]
        bind_artifact!(artifacts_toml, src_name, git_hash; platform=platform, download_info=download_info, force=true, lazy=true)
    end
end
