using BinaryBuilder

name = "CUDA"
version = v"10.1.168"

sources = [
    "https://developer.nvidia.com/compute/cuda/10.1/Prod/cluster_management/cuda_cluster_pkgs_10.1.168_418.67_rhel6.tar.gz" =>
    "965570c92de387cec04d77a2bdce26b6457b027c0b2b12dc537a5ca1c1aa82b3",
    "https://developer.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.168_mac.dmg" =>
    "a53d17c92b81bb8b8f812d0886a8c2ddf2730be6f5f2659aee11c0da207c2331",
    "https://developer.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.168_425.25_win10.exe" =>
    "52450b81a699cb75086e9d3d62abb2a33f823fcf5395444e57ebb5864cc2fd51",
]

# CUDA is weirdly organized, with several tools in bin/lib directories, some in dedicated
# subproject folders, and others in a catch-all extras/ directory. to simplify using
# the resulting binaries, we reorganize everything using a flat bin/lib structure.

# TODO: add back includes or nvcc is not functional. or remove nvcc/cicc/cudafe++

script = raw"""
cd ${WORKSPACE}/srcdir

apk add p7zip rpm

if [[ ${target} == x86_64-linux-gnu ]]; then
    cd cuda_cluster_pkgs*
    rpm2cpio cuda-cluster-runtime*.rpm | cpio -idmv
    rpm2cpio cuda-cluster-devel*.rpm | cpio -idmv
    cd usr/local/cuda*

    # essential files and hierarchy
    mv bin ${prefix}
    mv targets/x86_64-linux/lib ${prefix}
    mkdir ${prefix}/share

    # subprojects
    mv nvvm/bin/* ${prefix}/bin
    mv nvvm/lib64/* ${prefix}/lib
    mv nvvm/libdevice ${prefix}/share

    # extras
    mv extras/CUPTI/lib64/* ${prefix}/lib

    # clean up things we don't care about
    rm -f  ${prefix}/lib/*.a        # we can't use static libraries from Julia
    rm -rf ${prefix}/lib/stubs/     # stubs are a C/C++ thing
    rm -r  ${prefix}/bin/nsight_ee_plugins_manage.sh
    rm -r  ${prefix}/bin/cuda-install-samples-*.sh
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x ${WORKSPACE}/srcdir/cuda_*_win10.exe -bb

    mkdir -p ${prefix}/bin ${prefix}/share  # no lib folder; we don't ship static libs

    # subprojects
    for project in cuobjdump memcheck nvcc nvcc/nvvm nvdisasm curand cusparse npp cufft cublas cudart cusolver nvrtc nvgraph gpu-library-advisor nvprof nvprune; do
        mv ${project}/bin/* ${prefix}/bin/
    done
    mv nvcc/nvvm/libdevice ${prefix}/share

    # extras
    mv cupti/extras/CUPTI/lib64/* ${prefix}/bin/

    # clean up things we don't care about
    rm ${prefix}/bin/*.lib          # we can't use static libraries from Julia
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x ${WORKSPACE}/srcdir/cuda_*_mac.dmg
    7z x 5.hfs
    tar -zxvf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    cd Developer/NVIDIA/CUDA-*/

    # essential files and hierarchy
    mv bin ${prefix}
    mv lib ${prefix}
    mkdir ${prefix}/share

    # subprojects
    mv nvvm/bin/* ${prefix}/bin
    mv nvvm/lib/* ${prefix}/lib
    mv nvvm/libdevice ${prefix}/share

    # extras
    mv extras/CUPTI/lib/* ${prefix}/lib

    # clean up things we don't care about
    rm -f  ${prefix}/lib/*.a        # we can't use static libraries from Julia
    rm -rf ${prefix}/lib/stubs/     # stubs are a C/C++ thing
    rm -r  ${prefix}/bin/nsight_ee_plugins_manage.sh
    rm -f  ${prefix}/bin/.cuda_toolkit_uninstall_manifest_do_not_delete.txt
    rm -f  ${prefix}/bin/uninstall_cuda_*.pl
fi
"""

platforms = [
    Linux(:x86_64),
    Windows(:x86_64),
    MacOS(:x86_64),
]

# cuda-gdb, libnvjpeg, libOpenCL, libaccinj(64), libnvperf_host, libnvperf_target only on linux
# nsight, nvvp not on windows -- full installer

products(prefix) = [
    ExecutableProduct(prefix, "nvcc", :nvcc),
    ExecutableProduct(prefix, "cudafe++", :cudafepp),
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
