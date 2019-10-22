using BinaryBuilder

name = "CUDA"
version = v"10.1.243"

sources = [
    "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run" =>
    "e7c22dc21278eb1b82f34a60ad7640b41ad3943d929bebda3008b72536855d31",
    "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_mac.dmg" =>
    "432a2f07a793f21320edc5d10e7f68a8e4e89465c31e1696290bdb0ca7c8c997",
    "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_426.00_win10.exe" =>
    "35d3c99c58dd601b2a2caa28f44d828cae1eaf8beb70702732585fa001cd8ad7",
]

# CUDA is weirdly organized, with several tools in bin/lib directories, some in dedicated
# subproject folders, and others in a catch-all extras/ directory. to simplify using
# the resulting binaries, we reorganize everything using a flat bin/lib structure.

script = raw"""
cd ${WORKSPACE}/srcdir

apk add p7zip rpm

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh cuda_*_linux.run --target "${PWD}" --noexec --tar -xvf
    cd builds/cuda-toolkit

    # toplevel
    mv bin ${prefix}
    mv targets/x86_64-linux/lib ${prefix}
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
        [[ -d ${project}/lib64 ]] && mv ${project}/lib64/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvvp,nsight,computeprof}               # requires Java
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x ${WORKSPACE}/srcdir/cuda_*_win10.exe -bb

    # toplevel
    mkdir -p ${prefix}/bin ${prefix}/share
    # no lib folder; we don't ship static libs

    # nested
    for project in cuobjdump memcheck nvcc nvcc/nvvm nvdisasm curand cusparse npp cufft cublas cudart cusolver nvrtc nvgraph nvprof nvprune; do
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
    done
    mv nvcc/nvvm/libdevice ${prefix}/share
    mv cupti/extras/CUPTI/lib64/* ${prefix}/bin/

    # clean up
    rm    ${prefix}/bin/{nvcc,cicc,cudafe++}.exe   # CUDA C/C++ compiler
    rm    ${prefix}/bin/nvcc.profile
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/bin2c.exe                               # C/C++ utilities
    rm    ${prefix}/bin/*.lib                                   # we can't link statically
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x ${WORKSPACE}/srcdir/cuda_*_mac.dmg
    7z x 5.hfs
    tar -zxvf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    cd Developer/NVIDIA/CUDA-*/

    # toplevel
    mv bin ${prefix}
    mv lib ${prefix}
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
        [[ -d ${project}/lib ]] && mv ${project}/lib/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvvp,nsight,computeprof}               # requires Java
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/uninstall_cuda_*.pl
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
    rm    ${prefix}/bin/.cuda_toolkit_uninstall_manifest_do_not_delete.txt
fi
"""

platforms = [
    Linux(:x86_64),
    Windows(:x86_64),
    MacOS(:x86_64),
]

# cuda-gdb, libnvjpeg, libOpenCL, libaccinj(64), libnvperf_host, libnvperf_target only on linux

products(prefix) = [
    ExecutableProduct(prefix, "nvprof", :nvprof),
    ExecutableProduct(prefix, "ptxas", :ptxas),
    LibraryProduct(prefix, "libcudart", :libcudart),
    LibraryProduct(prefix, "libcufft", :libcufft),
    LibraryProduct(prefix, "libcufftw", :libcufftw),
    LibraryProduct(prefix, "libcurand", :libcurand),
    LibraryProduct(prefix, "libcublas", :libcublas),
    LibraryProduct(prefix, "libcusolver", :libcusolver),
    LibraryProduct(prefix, "libcusparse", :libcusparse),
    LibraryProduct(prefix, "libnvrtc", :libnvrtc),
]

dependencies = []

build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies; skip_audit=true)
