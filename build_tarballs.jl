using BinaryBuilder

# CUDA is weirdly organized, with several tools in bin/lib directories, some in dedicated
# subproject folders, and others in a catch-all extras/ directory. to simplify use of
# the resulting binaries, we reorganize everything using a flat bin/lib structure.

name = "CUDA"

platforms = [
    Linux(:x86_64),
    Windows(:x86_64),
    MacOS(:x86_64),
]

dependencies = []

# since this is a multi-version builder, make it possible to specify which version to build
function extract_flag(flag, val = nothing)
    for f in ARGS
        if startswith(f, flag)
            # Check if it's just `--flag` or if it's `--flag=foo`
            if f != flag
                val = split(f, '=')[2]
            end

            # Drop this value from our ARGS
            filter!(x -> x != f, ARGS)
            return (true, val)
        end
    end
    return (false, val)
end
_, requested_version = extract_flag("--version")

# we really don't want to download all sources when only building a single target,
# so make it possible to request so
_, requested_source = extract_flag("--source")


#
# CUDA 10.1
#

version = v"10.1.243"

sources = []
if requested_source == nothing || requested_source == "linux"
    push!(sources, "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run" =>
                   "e7c22dc21278eb1b82f34a60ad7640b41ad3943d929bebda3008b72536855d31")
end
if requested_source == nothing || requested_source == "mac"
    push!(sources, "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_mac.dmg" =>
                   "432a2f07a793f21320edc5d10e7f68a8e4e89465c31e1696290bdb0ca7c8c997")
end
if requested_source == nothing || requested_source == "win10"
    push!(sources, "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_426.00_win10.exe" =>
                   "35d3c99c58dd601b2a2caa28f44d828cae1eaf8beb70702732585fa001cd8ad7")
end

script = raw"""
mkdir ${WORKSPACE}/tmpdir
cd ${WORKSPACE}/srcdir

apk add p7zip rpm

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh *-cuda_*_linux.run --tmpdir="${WORKSPACE}/tmpdir" --target "${PWD}" --noexec
    rm *-cuda_*
    cd builds/cuda-toolkit

    # toplevel
    mv bin ${prefix}
    mv targets/x86_64-linux/lib ${prefix}
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]]   && mv ${project}/bin/*   ${prefix}/bin
        [[ -d ${project}/lib64 ]] && mv ${project}/lib64/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvprof,nvvp,nsight,computeprof}        # profiling
    rm    ${prefix}/bin/{cuda-memcheck,cuda-gdb,cuda-gdbserver} # debugging
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
    rm    ${prefix}/bin/cuda-uninstaller
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x *-cuda_*_win10.exe
    rm *-cuda_*

    # toplevel
    mkdir -p ${prefix}/bin ${prefix}/share
    # no lib folder; we don't ship static libs

    # nested
    for project in cuobjdump memcheck nvcc nvcc/nvvm nvdisasm curand cusparse npp cufft \
                   cublas cudart cusolver nvrtc nvgraph nvprof nvprune; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
    done
    mv nvcc/nvvm/libdevice ${prefix}/share
    mv cupti/extras/CUPTI/lib64/* ${prefix}/bin/

    # fixup
    chmod +x ${prefix}/bin/*.exe

    # clean up
    rm    ${prefix}/bin/{nvcc,cicc,cudafe++}.exe   # CUDA C/C++ compiler
    rm    ${prefix}/bin/nvcc.profile
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/bin2c.exe                               # C/C++ utilities
    rm    ${prefix}/bin/nvprof.exe                              # profiling
    rm    ${prefix}/bin/cuda-memcheck.exe                       # debugging
    rm    ${prefix}/bin/*.lib                                   # we can't link statically
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x *-cuda_*_mac.dmg 5.hfs
    rm *-cuda_*
    7z x 5.hfs
    rm 5.hfs
    tar -zxf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    rm -rf CUDAMacOSXInstaller
    cd Developer/NVIDIA/CUDA-*/

    # toplevel
    mv bin ${prefix}
    mv lib ${prefix}
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
        [[ -d ${project}/lib ]] && mv ${project}/lib/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvprof,nvvp,nsight,computeprof}        # profiling
    rm    ${prefix}/bin/cuda-memcheck                           # debugging
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/uninstall_cuda_*.pl
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
    rm    ${prefix}/bin/.cuda_toolkit_uninstall_manifest_do_not_delete.txt
fi
"""

products = [
    ExecutableProduct("nvdisasm", :nvdisasm),
    ExecutableProduct("cuobjdump", :cuobjdump),
    ExecutableProduct("fatbinary", :fatbinary),
    ExecutableProduct("ptxas", :ptxas),
    ExecutableProduct("nvprune", :nvprune),
    ExecutableProduct("nvlink", :nvlink),
    FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
    LibraryProduct(["libcudart", "cudart", "cudart64_101"], :libcudart),
    LibraryProduct(["libcufft", "cufft", "cufft64_10"], :libcufft),
    LibraryProduct(["libcufftw", "cufftw", "cufftw64_10"], :libcufftw),
    LibraryProduct(["libcurand", "curand", "curand64_10"], :libcurand),
    LibraryProduct(["libcublas", "cublas", "cublas64_10"], :libcublas),
    LibraryProduct(["libcusolver", "cusolver", "cusolver64_10"], :libcusolver),
    LibraryProduct(["libcusparse", "cusparse", "cusparse64_10"], :libcusparse),
]

if requested_version === nothing || requested_version == "10.1"
    build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
end


#
# CUDA 10.0
#

version = v"10.0.130"

sources = []
if requested_source == nothing || requested_source == "linux"
    push!(sources, "https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_410.48_linux" =>
                   "92351f0e4346694d0fcb4ea1539856c9eb82060c25654463bfd8574ec35ee39a")
end
if requested_source == nothing || requested_source == "mac"
    push!(sources, "https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_mac" =>
                   "4f76261ed46d0d08a597117b8cacba58824b8bb1e1d852745658ac873aae5c8e")
end
if requested_source == nothing || requested_source == "win10"
    push!(sources, "https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_411.31_win10" =>
                   "9dae54904570272c1fcdb10f5f19c71196b4fdf3ad722afa0862a238d7c75e6f")
end

script = raw"""
mkdir ${WORKSPACE}/tmpdir
cd ${WORKSPACE}/srcdir

apk add p7zip rpm

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh *-cuda_*_linux --tmpdir="${WORKSPACE}/tmpdir" --extract="${PWD}"
    rm *-cuda_*
    sh cuda-linux.*.run --noexec --keep
    rm *.run
    cd pkg

    # toplevel
    mv bin ${prefix}
    mv lib64 ${prefix}/lib
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
        [[ -d ${project}/lib64 ]] && mv ${project}/lib64/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvprof,nvvp,nsight}                    # profiling
    rm    ${prefix}/bin/{cuda-memcheck,cuda-gdb,cuda-gdbserver} # debugging
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x *-cuda_*_win10
    rm *-cuda_*

    # toplevel
    mkdir -p ${prefix}/bin ${prefix}/share
    # no lib folder; we don't ship static libs

    # nested
    for project in cuobjdump memcheck nvcc nvcc/nvvm nvdisasm curand cusparse npp cufft \
                   cublas cudart cusolver nvrtc nvgraph nvprof nvprune; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
    done
    mv nvcc/nvvm/libdevice ${prefix}/share
    mv cupti/extras/CUPTI/libx64/* ${prefix}/bin/

    # fixup
    chmod +x ${prefix}/bin/*.exe

    # clean up
    rm    ${prefix}/bin/{nvcc,cicc,cudafe++}.exe   # CUDA C/C++ compiler
    rm    ${prefix}/bin/nvcc.profile
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/bin2c.exe                               # C/C++ utilities
    rm    ${prefix}/bin/nvprof.exe                              # profiling
    rm    ${prefix}/bin/cuda-memcheck.exe                       # debugging
    rm    ${prefix}/bin/*.lib                                   # we can't link statically
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x *-cuda_*_mac 5.hfs
    rm *-cuda_*
    7z x 5.hfs
    rm 5.hfs
    tar -zxf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    rm -rf CUDAMacOSXInstaller
    cd Developer/NVIDIA/CUDA-*/

    # toplevel
    mv bin ${prefix}
    mv lib ${prefix}
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
        [[ -d ${project}/lib ]] && mv ${project}/lib/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvprof,nvvp,nsight}                    # profiling
    rm    ${prefix}/bin/cuda-memcheck                           # debugging
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/uninstall_cuda_*.pl
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
    rm    ${prefix}/bin/.cuda_toolkit_uninstall_manifest_do_not_delete.txt
fi
"""

products = [
    ExecutableProduct("nvdisasm", :nvdisasm),
    ExecutableProduct("cuobjdump", :cuobjdump),
    ExecutableProduct("fatbinary", :fatbinary),
    ExecutableProduct("ptxas", :ptxas),
    ExecutableProduct("nvprune", :nvprune),
    ExecutableProduct("nvlink", :nvlink),
    FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
    LibraryProduct(["libcudart", "cudart", "cudart64_100"], :libcudart),
    LibraryProduct(["libcufft", "cufft", "cufft64_100"], :libcufft),
    LibraryProduct(["libcufftw", "cufftw", "cufftw64_100"], :libcufftw),
    LibraryProduct(["libcurand", "curand", "curand64_100"], :libcurand),
    LibraryProduct(["libcublas", "cublas", "cublas64_100"], :libcublas),
    LibraryProduct(["libcusolver", "cusolver", "cusolver64_100"], :libcusolver),
    LibraryProduct(["libcusparse", "cusparse", "cusparse64_100"], :libcusparse),
]

if requested_version === nothing || requested_version == "10.0"
    build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
end


#
# CUDA 9.2
#

version = v"9.2.148"

sources = []
if requested_source == nothing || requested_source == "linux"
    push!(sources, "https://developer.nvidia.com/compute/cuda/9.2/Prod2/local_installers/cuda_9.2.148_396.37_linux" =>
                   "f5454ec2cfdf6e02979ed2b1ebc18480d5dded2ef2279e9ce68a505056da8611")
end
if requested_source == nothing || requested_source == "mac"
    push!(sources, "https://developer.nvidia.com/compute/cuda/9.2/Prod2/local_installers/cuda_9.2.148_mac" =>
                   "defb095aa002301f01b2f41312c9b1630328847800baa1772fe2bbb811d5fa9f")
end
if requested_source == nothing || requested_source == "win10"
    push!(sources, "https://developer.nvidia.com/compute/cuda/9.2/Prod2/local_installers2/cuda_9.2.148_win10" =>
                   "7d99a6d135587d029c2cf159ade4e71c02fc1a922a5ffd06238b2bde8bedc362")
end

script = raw"""
mkdir ${WORKSPACE}/tmpdir
cd ${WORKSPACE}/srcdir

apk add p7zip rpm

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh *-cuda_*_linux --tmpdir="${WORKSPACE}/tmpdir" --extract="${PWD}"
    rm *-cuda_*
    sh cuda-linux.*.run --noexec --keep
    rm *.run
    cd pkg

    # toplevel
    mv bin ${prefix}
    mv lib64 ${prefix}/lib
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
        [[ -d ${project}/lib64 ]] && mv ${project}/lib64/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvprof,nvvp,nsight}                    # profiling
    rm    ${prefix}/bin/{cuda-memcheck,cuda-gdb,cuda-gdbserver} # debugging
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x *-cuda_*_win10
    rm *-cuda_*

    # toplevel
    mkdir -p ${prefix}/bin ${prefix}/share
    # no lib folder; we don't ship static libs

    # nested
    for project in cuobjdump memcheck nvcc nvcc/nvvm nvdisasm curand cusparse npp cufft \
                   cublas cudart cusolver nvrtc nvgraph nvprof nvprune; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
    done
    mv nvcc/nvvm/libdevice ${prefix}/share
    mv cupti/extras/CUPTI/libx64/* ${prefix}/bin/

    # fixup
    chmod +x ${prefix}/bin/*.exe

    # clean up
    rm    ${prefix}/bin/{nvcc,cicc,cudafe++}.exe   # CUDA C/C++ compiler
    rm    ${prefix}/bin/nvcc.profile
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/bin2c.exe                               # C/C++ utilities
    rm    ${prefix}/bin/nvprof.exe                              # profiling
    rm    ${prefix}/bin/cuda-memcheck.exe                       # debugging
    rm    ${prefix}/bin/*.lib                                   # we can't link statically
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x *-cuda_*_mac
    rm *-cuda_*
    tar -zxf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    rm -rf CUDAMacOSXInstaller
    cd Developer/NVIDIA/CUDA-*/

    # toplevel
    mv bin ${prefix}
    mv lib ${prefix}
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
        [[ -d ${project}/lib ]] && mv ${project}/lib/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvprof,nvvp,nsight}                    # profiling
    rm    ${prefix}/bin/cuda-memcheck                           # debugging
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/uninstall_cuda_*.pl
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
    rm    ${prefix}/bin/.cuda_toolkit_uninstall_manifest_do_not_delete.txt
fi
"""

products = [
    ExecutableProduct("nvdisasm", :nvdisasm),
    ExecutableProduct("cuobjdump", :cuobjdump),
    ExecutableProduct("fatbinary", :fatbinary),
    ExecutableProduct("ptxas", :ptxas),
    ExecutableProduct("nvprune", :nvprune),
    ExecutableProduct("nvlink", :nvlink),
    FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
    LibraryProduct(["libcudart", "cudart", "cudart64_92"], :libcudart),
    LibraryProduct(["libcufft", "cufft", "cufft64_92"], :libcufft),
    LibraryProduct(["libcufftw", "cufftw", "cufftw64_92"], :libcufftw),
    LibraryProduct(["libcurand", "curand", "curand64_92"], :libcurand),
    LibraryProduct(["libcublas", "cublas", "cublas64_92"], :libcublas),
    LibraryProduct(["libcusolver", "cusolver", "cusolver64_92"], :libcusolver),
    LibraryProduct(["libcusparse", "cusparse", "cusparse64_92"], :libcusparse),
]

if requested_version === nothing || requested_version == "9.2"
    build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
end


#
# CUDA 9.0
#

version = v"9.0.176"

sources = []
if requested_source == nothing || requested_source == "linux"
    push!(sources, "https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_384.81_linux-run" =>
                   "96863423feaa50b5c1c5e1b9ec537ef7ba77576a3986652351ae43e66bcd080c")
end
if requested_source == nothing || requested_source == "mac"
    push!(sources, "https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_mac-dmg" =>
                   "8fad950098337d2611d64617ca9f62c319d97c5e882b8368ed196e994bdaf225")
end
if requested_source == nothing || requested_source == "win10"
    push!(sources, "https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_win10-exe" =>
                   "615946c36c415d7d37b22dbade54469f0ed037b1b6470d6b8a108ab585e2621a")
end

script = raw"""
mkdir ${WORKSPACE}/tmpdir
cd ${WORKSPACE}/srcdir

apk add p7zip rpm

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh *-cuda_*_linux-run --tmpdir="${WORKSPACE}/tmpdir" --extract="${PWD}"
    rm *-cuda_*
    sh cuda-linux.*.run --noexec --keep
    rm *.run
    cd pkg

    # toplevel
    mv bin ${prefix}
    mv lib64 ${prefix}/lib
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
        [[ -d ${project}/lib64 ]] && mv ${project}/lib64/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvprof,nvvp,nsight}                    # profiling
    rm    ${prefix}/bin/{cuda-memcheck,cuda-gdb,cuda-gdbserver} # debugging
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x *-cuda_*_win10-exe
    rm *-cuda_*

    # toplevel
    mkdir -p ${prefix}/bin ${prefix}/share
    # no lib folder; we don't ship static libs

    # nested
    for project in cuobjdump memcheck compiler compiler/nvvm nvdisasm curand cusparse npp \
                   cufft cublas cudart cusolver nvrtc nvgraph command_line_tools; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
    done
    mv compiler/nvvm/libdevice ${prefix}/share
    mv command_line_tools/extras/CUPTI/libx64/* ${prefix}/bin/

    # fixup
    chmod +x ${prefix}/bin/*.exe

    # clean up
    rm    ${prefix}/bin/{nvcc,cicc,cudafe++}.exe   # CUDA C/C++ compiler
    rm    ${prefix}/bin/nvcc.profile
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/bin2c.exe                               # C/C++ utilities
    rm    ${prefix}/bin/nvprof.exe                              # profiling
    rm    ${prefix}/bin/cuda-memcheck.exe                       # debugging
    rm    ${prefix}/bin/*.lib                                   # we can't link statically
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x *-cuda_*_mac-dmg
    rm *-cuda_*
    tar -zxf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    rm -rf CUDAMacOSXInstaller
    cd Developer/NVIDIA/CUDA-*/

    # toplevel
    mv bin ${prefix}
    mv lib ${prefix}
    mkdir ${prefix}/share

    # nested
    for project in nvvm extras/CUPTI; do
        [[ -d ${project} ]] || { echo "${project} does not exist!"; exit 1; }
        [[ -d ${project}/bin ]] && mv ${project}/bin/* ${prefix}/bin
        [[ -d ${project}/lib ]] && mv ${project}/lib/* ${prefix}/lib
    done
    mv nvvm/libdevice ${prefix}/share

    # clean up
    rm    ${prefix}/bin/{nvcc,nvcc.profile,cicc,cudafe++}       # CUDA C/C++ compiler
    rm -r ${prefix}/bin/crt/
    rm    ${prefix}/bin/{gpu-library-advisor,bin2c}             # C/C++ utilities
    rm    ${prefix}/bin/{nvprof,nvvp,nsight}                    # profiling
    rm    ${prefix}/bin/cuda-memcheck                           # debugging
    rm    ${prefix}/lib/*.a                                     # we can't link statically
    rm -r ${prefix}/lib/stubs/                                  # stubs are a C/C++ thing
    rm    ${prefix}/bin/uninstall_cuda_*.pl
    rm    ${prefix}/bin/nsight_ee_plugins_manage.sh
    rm    ${prefix}/bin/.cuda_toolkit_uninstall_manifest_do_not_delete.txt
fi
"""

products = [
    ExecutableProduct("nvdisasm", :nvdisasm),
    ExecutableProduct("cuobjdump", :cuobjdump),
    ExecutableProduct("fatbinary", :fatbinary),
    ExecutableProduct("ptxas", :ptxas),
    ExecutableProduct("nvprune", :nvprune),
    ExecutableProduct("nvlink", :nvlink),
    FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
    LibraryProduct(["libcudart", "cudart", "cudart64_90"], :libcudart),
    LibraryProduct(["libcufft", "cufft", "cufft64_90"], :libcufft),
    LibraryProduct(["libcufftw", "cufftw", "cufftw64_90"], :libcufftw),
    LibraryProduct(["libcurand", "curand", "curand64_90"], :libcurand),
    LibraryProduct(["libcublas", "cublas", "cublas64_90"], :libcublas),
    LibraryProduct(["libcusolver", "cusolver", "cusolver64_90"], :libcusolver),
    LibraryProduct(["libcusparse", "cusparse", "cusparse64_90"], :libcusparse),
]

if requested_version === nothing || requested_version == "9.0"
    build_tarballs(ARGS, name, version, sources, script, platforms, products, dependencies)
end
