using BinaryBuilder

# CUDA is weirdly organized, with several tools in bin/lib directories, some in dedicated
# subproject folders, and others in a catch-all extras/ directory. to simplify use of
# the resulting binaries, we reorganize everything using a flat bin/lib structure.
#
# note that we only copy (select) files and libraries that we are allowed to redistribute
# as per https://docs.nvidia.com/cuda/eula/index.html#attachment-a

name = "CUDA"
tag = v"0.3.0"

dependencies = []

output = Dict()

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
requested_version = VersionNumber(requested_version)
wants_version(ver::VersionNumber) = requested_version === nothing || requested_version == ver

# we really don't want to download all sources when only building a single target,
# so make it possible to request so (this especially matters on Travis CI)
requested_targets = filter(f->!startswith(f, "--"), ARGS)
wants_target(target::String) = isempty(requested_targets) || target in requested_targets
wants_target(regex::Regex) = isempty(requested_targets) || any(target->occursin(regex, target), requested_targets)


#
# CUDA 10.2
#

cuda_version = v"10.2.89"
output[cuda_version] = Dict()

# NOTE: although 10.2 is supposed to be the last version supporting macOS,
#       it doesn't ship NVTX or CUDNN anymore, so we don't bother.

sources_linux = [
    "http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_440.33.01_linux.run" =>
    "560d07fdcf4a46717f2242948cd4f92c5f9b6fc7eae10dd996614da913d5ca11"
]
sources_windows = [
    "http://developer.download.nvidia.com/compute/cuda/10.2/Prod/local_installers/cuda_10.2.89_441.22_win10.exe" =>
    "b538271c4d9ffce1a8520bf992d9bd23854f0f29cee67f48c6139e4cf301e253"
]

script = raw"""
cd ${WORKSPACE}/srcdir

# use a temporary directory to avoid running out of tmpfs in srcdir on Travis
temp=${WORKSPACE}/tmpdir
mkdir ${temp}

apk add p7zip

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh *-cuda_*_linux.run --tmpdir="${temp}" --target "${temp}" --noexec
    cd ${temp}/builds/cuda-toolkit
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include
    mv targets/x86_64-linux/lib .

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # headers (we copy them all, CUDA on Linux doesn't split in subprojects)
    mv targets/x86_64-linux/include/* ${prefix}/include
    rm -rf ${prefix}/include/thrust

    # CUDA Runtime
    mv lib/libcudart.so* lib/libcudadevrt.a ${prefix}/lib

    # CUDA FFT Library
    mv lib/libcufft.so* lib/libcufftw.so* ${prefix}/lib

    # CUDA BLAS Library
    mv lib/libcublas.so* lib/libcublasLt.so* ${prefix}/lib

    # NVIDIA "Drop-in" BLAS Library
    mv lib/libnvblas.so* ${prefix}/lib

    # CUDA Sparse Matrix Library
    mv lib/libcusparse.so* ${prefix}/lib

    # CUDA Linear Solver Library
    mv lib/libcusolver.so* ${prefix}/lib

    # CUDA Random Number Generation Library
    mv lib/libcurand.so* ${prefix}/lib

    # CUDA Accelerated Graph Library
    mv lib/libnvgraph.so* ${prefix}/lib

    # NVIDIA Performance Primitives Library
    mv lib/libnpp*.so* ${prefix}/lib

    # NVIDIA Optimizing Compiler Library
    mv nvvm/lib64/libnvvm.so* ${prefix}/lib
    mv nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv extras/CUPTI/lib64/libcupti.so* ${prefix}/lib
    mv extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    mv lib/libnvToolsExt.so* ${prefix}/lib

    # CUDA Disassembler
    mv bin/nvdisasm ${prefix}/bin
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x *-cuda_*_win10.exe -o${temp}
    cd ${temp}
    7z x "CUDAVisualStudioIntegration/NVIDIA NVTX Installer.x86_64".*.msi -o${temp}/nvtx_installer
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # CUDA Runtime
    mv cudart/bin/cudart64_*.dll ${prefix}/bin
    mv nvcc/lib/x64/cudadevrt.lib ${prefix}/lib
    mv nvcc/include/* ${prefix}/include

    # CUDA FFT Library
    mv cufft/bin/cufft64_*.dll cufft/bin/cufftw64_*.dll ${prefix}/bin
    mv cufft_dev/include/* ${prefix}/include

    # CUDA BLAS Library
    mv cublas/bin/cublas64_*.dll cublas/bin/cublasLt64_*.dll ${prefix}/bin
    mv cublas_dev/include/* ${prefix}/include

    # NVIDIA "Drop-in" BLAS Library
    mv cublas/bin/nvblas64_*.dll ${prefix}/bin

    # CUDA Sparse Matrix Library
    mv cusparse/bin/cusparse64_*.dll ${prefix}/bin
    mv cusparse_dev/include/* ${prefix}/include

    # CUDA Linear Solver Library
    mv cusolver/bin/cusolver64_*.dll ${prefix}/bin
    mv cusolver_dev/include/* ${prefix}/include

    # CUDA Random Number Generation Library
    mv curand/bin/curand64_*.dll ${prefix}/bin
    mv curand_dev/include/* ${prefix}/include

    # CUDA Accelerated Graph Library
    mv nvgraph/bin/nvgraph64_*.dll ${prefix}/bin
    mv nvgraph_dev/include/* ${prefix}/include

    # NVIDIA Performance Primitives Library
    mv npp/bin/npp*64_*.dll ${prefix}/bin
    mv npp_dev/include/* ${prefix}/include

    # NVIDIA Optimizing Compiler Library
    mv nvcc/nvvm/bin/nvvm64_*.dll ${prefix}/bin
    mv nvcc/nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvcc/nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv cupti/extras/CUPTI/lib64/cupti64_*.dll ${prefix}/bin
    mv cupti/extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    for file in nvtx_installer/*.*_*; do
        mv $file $(echo $file | sed 's/\.\(\w*\)_.*/.\1/')
    done
    mv nvtx_installer/nvToolsExt64_1.dll ${prefix}/bin
    mv nvtx_installer/*.h ${prefix}/include

    # CUDA Disassembler
    mv nvdisasm/bin/nvdisasm.exe ${prefix}/bin
    chmod +x ${prefix}/bin/nvdisasm.exe
fi
"""

products = [
    LibraryProduct(["libcudart", "cudart64_102"], :libcudart),
    FileProduct(["lib/libcudadevrt.a", "lib/cudadevrt.lib"], :libcudadevrt),
    LibraryProduct(["libcufft", "cufft64_10"], :libcufft),
    LibraryProduct(["libcufftw", "cufftw64_10"], :libcufftw),
    LibraryProduct(["libcublas", "cublas64_10"], :libcublas),
    LibraryProduct(["libcublasLt", "cublasLt64_10"], :libcublasLt),
    LibraryProduct(["libnvblas", "nvblas64_10"], :libnvblas),
    LibraryProduct(["libcusparse", "cusparse64_10"], :libcusparse),
    LibraryProduct(["libcusolver", "cusolver64_10"], :libcusolver),
    LibraryProduct(["libcurand", "curand64_10"], :libcurand),
    LibraryProduct(["libnvgraph", "nvgraph64_10"], :libcurand),
    LibraryProduct(["libnppc", "nppc64_10"], :libnppc),
    LibraryProduct(["libnppial", "nppial64_10"], :libnppial),
    LibraryProduct(["libnppicc", "nppicc64_10"], :libnppicc),
    LibraryProduct(["libnppicom", "nppicom64_10"], :libnppicom),
    LibraryProduct(["libnppidei", "nppidei64_10"], :libnppidei),
    LibraryProduct(["libnppif", "nppif64_10"], :libnppif),
    LibraryProduct(["libnppig", "nppig64_10"], :libnppig),
    LibraryProduct(["libnppim", "nppim64_10"], :libnppim),
    LibraryProduct(["libnppist", "nppist64_10"], :libnppist),
    LibraryProduct(["libnppisu", "nppisu64_10"], :libnppisu),
    LibraryProduct(["libnppitc", "nppitc64_10"], :libnppitc),
    LibraryProduct(["libnpps", "npps64_10"], :libnpps),
    LibraryProduct(["libnvvm", "nvvm64_33_0"], :libnvvm),
    FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
    LibraryProduct(["libcupti", "cupti64_102"], :libcupti),
    LibraryProduct(["libnvToolsExt", "nvToolsExt64_1"], :libnvtoolsext),
    ExecutableProduct("nvdisasm", :nvdisasm),
]

if wants_version(v"10.2")
    if wants_target("x86_64-linux-gnu")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_linux, script, [Linux(:x86_64)], products, dependencies))
    end
    if wants_target("x86_64-w64-mingw32")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_windows, script, [Windows(:x86_64)], products, dependencies))
    end
end


#
# CUDA 10.1
#

cuda_version = v"10.1.243"
output[cuda_version] = Dict()

sources_linux = [
    "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_418.87.00_linux.run" =>
    "e7c22dc21278eb1b82f34a60ad7640b41ad3943d929bebda3008b72536855d31"
]
sources_macos = [
    "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_mac.dmg" =>
    "432a2f07a793f21320edc5d10e7f68a8e4e89465c31e1696290bdb0ca7c8c997"
]
sources_windows = [
    "http://developer.download.nvidia.com/compute/cuda/10.1/Prod/local_installers/cuda_10.1.243_426.00_win10.exe" =>
    "35d3c99c58dd601b2a2caa28f44d828cae1eaf8beb70702732585fa001cd8ad7"
]

script = raw"""
cd ${WORKSPACE}/srcdir

# use a temporary directory to avoid running out of tmpfs in srcdir on Travis
temp=${WORKSPACE}/tmpdir
mkdir ${temp}

apk add p7zip

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh *-cuda_*_linux.run --tmpdir="${temp}" --target "${temp}" --noexec
    cd ${temp}/builds/cuda-toolkit
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include
    mv targets/x86_64-linux/lib .

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # headers (we copy them all, CUDA on Linux doesn't split in subprojects)
    mv targets/x86_64-linux/include/* ${prefix}/include
    rm -rf ${prefix}/include/thrust

    # CUDA Runtime
    mv lib/libcudart.so* lib/libcudadevrt.a ${prefix}/lib

    # CUDA FFT Library
    mv lib/libcufft.so* lib/libcufftw.so* ${prefix}/lib

    # CUDA BLAS Library
    mv lib/libcublas.so* lib/libcublasLt.so* ${prefix}/lib

    # NVIDIA "Drop-in" BLAS Library
    mv lib/libnvblas.so* ${prefix}/lib

    # CUDA Sparse Matrix Library
    mv lib/libcusparse.so* ${prefix}/lib

    # CUDA Linear Solver Library
    mv lib/libcusolver.so* ${prefix}/lib

    # CUDA Random Number Generation Library
    mv lib/libcurand.so* ${prefix}/lib

    # CUDA Accelerated Graph Library
    mv lib/libnvgraph.so* ${prefix}/lib

    # NVIDIA Performance Primitives Library
    mv lib/libnpp*.so* ${prefix}/lib

    # NVIDIA Optimizing Compiler Library
    mv nvvm/lib64/libnvvm.so* ${prefix}/lib
    mv nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv extras/CUPTI/lib64/libcupti.so* ${prefix}/lib
    mv extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    mv lib/libnvToolsExt.so* ${prefix}/lib

    # CUDA Disassembler
    mv bin/nvdisasm ${prefix}/bin
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x *-cuda_*_win10.exe -o${temp}
    cd ${temp}
    7z x "CUDAVisualStudioIntegration/NVIDIA NVTX Installer.x86_64".*.msi -o${temp}/nvtx_installer
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # CUDA Runtime
    mv cudart/bin/cudart64_*.dll ${prefix}/bin
    mv nvcc/lib/x64/cudadevrt.lib ${prefix}/lib
    mv nvcc/include/* ${prefix}/include

    # CUDA FFT Library
    mv cufft/bin/cufft64_*.dll cufft/bin/cufftw64_*.dll ${prefix}/bin
    mv cufft_dev/include/* ${prefix}/include

    # CUDA BLAS Library
    mv cublas/bin/cublas64_*.dll cublas/bin/cublasLt64_*.dll ${prefix}/bin
    mv cublas_dev/include/* ${prefix}/include

    # NVIDIA "Drop-in" BLAS Library
    mv cublas/bin/nvblas64_*.dll ${prefix}/bin

    # CUDA Sparse Matrix Library
    mv cusparse/bin/cusparse64_*.dll ${prefix}/bin
    mv cusparse_dev/include/* ${prefix}/include

    # CUDA Linear Solver Library
    mv cusolver/bin/cusolver64_*.dll ${prefix}/bin
    mv cusolver_dev/include/* ${prefix}/include

    # CUDA Random Number Generation Library
    mv curand/bin/curand64_*.dll ${prefix}/bin
    mv curand_dev/include/* ${prefix}/include

    # CUDA Accelerated Graph Library
    mv nvgraph/bin/nvgraph64_*.dll ${prefix}/bin
    mv nvgraph_dev/include/* ${prefix}/include

    # NVIDIA Performance Primitives Library
    mv npp/bin/npp*64_*.dll ${prefix}/bin
    mv npp_dev/include/* ${prefix}/include

    # NVIDIA Optimizing Compiler Library
    mv nvcc/nvvm/bin/nvvm64_*.dll ${prefix}/bin
    mv nvcc/nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvcc/nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv cupti/extras/CUPTI/lib64/cupti64_*.dll ${prefix}/bin
    mv cupti/extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    for file in nvtx_installer/*.*_*; do
        mv $file $(echo $file | sed 's/\.\(\w*\)_.*/.\1/')
    done
    mv nvtx_installer/nvToolsExt64_1.dll ${prefix}/bin
    mv nvtx_installer/*.h ${prefix}/include

    # CUDA Disassembler
    mv nvdisasm/bin/nvdisasm.exe ${prefix}/bin
    chmod +x ${prefix}/bin/nvdisasm.exe
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x *-cuda_*_mac.dmg 5.hfs -o${temp}
    cd ${temp}
    7z x 5.hfs
    tar -zxf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    cd Developer/NVIDIA/CUDA-*/
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # headers (we copy them all, CUDA on macOS doesn't split in subprojects)
    mv include/* ${prefix}/include
    rm -rf ${prefix}/include/thrust

    # CUDA Runtime
    mv lib/libcudart.*dylib lib/libcudadevrt.a ${prefix}/lib

    # CUDA FFT Library
    mv lib/libcufft.*dylib lib/libcufftw.*dylib ${prefix}/lib

    # CUDA BLAS Library
    mv lib/libcublas.*dylib lib/libcublasLt.*dylib ${prefix}/lib

    # NVIDIA "Drop-in" BLAS Library
    mv lib/libnvblas.*dylib ${prefix}/lib

    # CUDA Sparse Matrix Library
    mv lib/libcusparse.*dylib ${prefix}/lib

    # CUDA Linear Solver Library
    mv lib/libcusolver.*dylib ${prefix}/lib

    # CUDA Random Number Generation Library
    mv lib/libcurand.*dylib ${prefix}/lib

    # CUDA Accelerated Graph Library
    mv lib/libnvgraph.*dylib ${prefix}/lib

    # NVIDIA Performance Primitives Library
    mv lib/libnpp*.*dylib ${prefix}/lib

    # NVIDIA Optimizing Compiler Library
    mv nvvm/lib/libnvvm.*dylib ${prefix}/lib
    mv nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv extras/CUPTI/lib64/libcupti.*dylib ${prefix}/lib
    mv extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    mv lib/libnvToolsExt.*dylib ${prefix}/lib

    # CUDA Disassembler
    mv bin/nvdisasm ${prefix}/bin
fi
"""

products = [
    LibraryProduct(["libcudart", "cudart64_101"], :libcudart),
    FileProduct(["lib/libcudadevrt.a", "lib/cudadevrt.lib"], :libcudadevrt),
    LibraryProduct(["libcufft", "cufft64_10"], :libcufft),
    LibraryProduct(["libcufftw", "cufftw64_10"], :libcufftw),
    LibraryProduct(["libcublas", "cublas64_10"], :libcublas),
    LibraryProduct(["libcublasLt", "cublasLt64_10"], :libcublasLt),
    LibraryProduct(["libnvblas", "nvblas64_10"], :libnvblas),
    LibraryProduct(["libcusparse", "cusparse64_10"], :libcusparse),
    LibraryProduct(["libcusolver", "cusolver64_10"], :libcusolver),
    LibraryProduct(["libcurand", "curand64_10"], :libcurand),
    LibraryProduct(["libnvgraph", "nvgraph64_10"], :libcurand),
    LibraryProduct(["libnppc", "nppc64_10"], :libnppc),
    LibraryProduct(["libnppial", "nppial64_10"], :libnppial),
    LibraryProduct(["libnppicc", "nppicc64_10"], :libnppicc),
    LibraryProduct(["libnppicom", "nppicom64_10"], :libnppicom),
    LibraryProduct(["libnppidei", "nppidei64_10"], :libnppidei),
    LibraryProduct(["libnppif", "nppif64_10"], :libnppif),
    LibraryProduct(["libnppig", "nppig64_10"], :libnppig),
    LibraryProduct(["libnppim", "nppim64_10"], :libnppim),
    LibraryProduct(["libnppist", "nppist64_10"], :libnppist),
    LibraryProduct(["libnppisu", "nppisu64_10"], :libnppisu),
    LibraryProduct(["libnppitc", "nppitc64_10"], :libnppitc),
    LibraryProduct(["libnpps", "npps64_10"], :libnpps),
    LibraryProduct(["libnvvm", "nvvm64_33_0"], :libnvvm),
    FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
    LibraryProduct(["libcupti", "cupti64_101"], :libcupti),
    LibraryProduct(["libnvToolsExt", "nvToolsExt64_1"], :libnvtoolsext),
    ExecutableProduct("nvdisasm", :nvdisasm),
]

if wants_version(v"10.1")
    if wants_target("x86_64-linux-gnu")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_linux, script, [Linux(:x86_64)], products, dependencies))
    end
    if wants_target(r"x86_64-apple-darwin")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_macos, script, [MacOS(:x86_64)], products, dependencies))
    end
    if wants_target("x86_64-w64-mingw32")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_windows, script, [Windows(:x86_64)], products, dependencies))
    end
end


#
# CUDA 10.0
#

cuda_version = v"10.0.130"
output[cuda_version] = Dict()

sources_linux = [
    "https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_410.48_linux" =>
    "92351f0e4346694d0fcb4ea1539856c9eb82060c25654463bfd8574ec35ee39a"
]
sources_macos = [
    "https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_mac" =>
    "4f76261ed46d0d08a597117b8cacba58824b8bb1e1d852745658ac873aae5c8e"
]
sources_windows = [
    "https://developer.nvidia.com/compute/cuda/10.0/Prod/local_installers/cuda_10.0.130_411.31_win10" =>
    "9dae54904570272c1fcdb10f5f19c71196b4fdf3ad722afa0862a238d7c75e6f"
]

script = raw"""
cd ${WORKSPACE}/srcdir

# use a temporary directory to avoid running out of tmpfs in srcdir on Travis
temp=${WORKSPACE}/tmpdir
mkdir ${temp}

apk add p7zip

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh *-cuda_*_linux --tmpdir="${temp}" --extract="${temp}"
    cd ${temp}
    sh cuda-linux.*.run --noexec --keep
    cd pkg
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # headers (we copy them all, CUDA on Linux doesn't split in subprojects)
    mv include/* ${prefix}/include
    rm -rf ${prefix}/include/thrust

    # CUDA Runtime
    mv lib64/libcudart.so* lib64/libcudadevrt.a ${prefix}/lib

    # CUDA FFT Library
    mv lib64/libcufft.so* lib64/libcufftw.so* ${prefix}/lib

    # CUDA BLAS Library
    mv lib64/libcublas.so* ${prefix}/lib

    # NVIDIA "Drop-in" BLAS Library
    mv lib64/libnvblas.so* ${prefix}/lib

    # CUDA Sparse Matrix Library
    mv lib64/libcusparse.so* ${prefix}/lib

    # CUDA Linear Solver Library
    mv lib64/libcusolver.so* ${prefix}/lib

    # CUDA Random Number Generation Library
    mv lib64/libcurand.so* ${prefix}/lib

    # CUDA Accelerated Graph Library
    mv lib64/libnvgraph.so* ${prefix}/lib

    # NVIDIA Performance Primitives Library
    mv lib64/libnpp*.so* ${prefix}/lib

    # NVIDIA Optimizing Compiler Library
    mv nvvm/lib64/libnvvm.so* ${prefix}/lib
    mv nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv extras/CUPTI/lib64/libcupti.so* ${prefix}/lib
    mv extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    mv lib64/libnvToolsExt.so* ${prefix}/lib

    # CUDA Disassembler
    mv bin/nvdisasm ${prefix}/bin
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x *-cuda_*_win10 -o${temp}
    cd ${temp}
    7z x "CUDAVisualStudioIntegration/NVIDIA NVTX Installer.x86_64".*.msi -o${temp}/nvtx_installer
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # CUDA Runtime
    mv cudart/bin/cudart64_*.dll ${prefix}/bin
    mv nvcc/lib/x64/cudadevrt.lib ${prefix}/lib
    mv nvcc/include/* ${prefix}/include

    # CUDA FFT Library
    mv cufft/bin/cufft64_*.dll cufft/bin/cufftw64_*.dll ${prefix}/bin
    mv cufft_dev/include/* ${prefix}/include

    # CUDA BLAS Library
    mv cublas/bin/cublas64_*.dll ${prefix}/bin
    mv cublas_dev/include/* ${prefix}/include

    # NVIDIA "Drop-in" BLAS Library
    mv cublas/bin/nvblas64_*.dll ${prefix}/bin

    # CUDA Sparse Matrix Library
    mv cusparse/bin/cusparse64_*.dll ${prefix}/bin
    mv cusparse_dev/include/* ${prefix}/include

    # CUDA Linear Solver Library
    mv cusolver/bin/cusolver64_*.dll ${prefix}/bin
    mv cusolver_dev/include/* ${prefix}/include

    # CUDA Random Number Generation Library
    mv curand/bin/curand64_*.dll ${prefix}/bin
    mv curand_dev/include/* ${prefix}/include

    # CUDA Accelerated Graph Library
    mv nvgraph/bin/nvgraph64_*.dll ${prefix}/bin
    mv nvgraph_dev/include/* ${prefix}/include

    # NVIDIA Performance Primitives Library
    mv npp/bin/npp*64_*.dll ${prefix}/bin
    mv npp_dev/include/* ${prefix}/include

    # NVIDIA Optimizing Compiler Library
    mv nvcc/nvvm/bin/nvvm64_*.dll ${prefix}/bin
    mv nvcc/nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvcc/nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv cupti/extras/CUPTI/libx64/cupti64_*.dll ${prefix}/bin
    mv cupti/extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    for file in nvtx_installer/*.*_*; do
        mv $file $(echo $file | sed 's/\.\(\w*\)_.*/.\1/')
    done
    mv nvtx_installer/nvToolsExt64_1.dll ${prefix}/bin
    mv nvtx_installer/*.h ${prefix}/include

    # CUDA Disassembler
    mv nvdisasm/bin/nvdisasm.exe ${prefix}/bin
    chmod +x ${prefix}/bin/nvdisasm.exe
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x *-cuda_*_mac 5.hfs -o${temp}
    cd ${temp}
    7z x 5.hfs
    tar -zxf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    cd Developer/NVIDIA/CUDA-*/
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # headers (we copy them all, CUDA on macOS doesn't split in subprojects)
    mv include/* ${prefix}/include
    rm -rf ${prefix}/include/thrust

    # CUDA Runtime
    mv lib/libcudart.*dylib lib/libcudadevrt.a ${prefix}/lib

    # CUDA FFT Library
    mv lib/libcufft.*dylib lib/libcufftw.*dylib ${prefix}/lib

    # CUDA BLAS Library
    mv lib/libcublas.*dylib ${prefix}/lib

    # NVIDIA "Drop-in" BLAS Library
    mv lib/libnvblas.*dylib ${prefix}/lib

    # CUDA Sparse Matrix Library
    mv lib/libcusparse.*dylib ${prefix}/lib

    # CUDA Linear Solver Library
    mv lib/libcusolver.*dylib ${prefix}/lib

    # CUDA Random Number Generation Library
    mv lib/libcurand.*dylib ${prefix}/lib

    # CUDA Accelerated Graph Library
    mv lib/libnvgraph.*dylib ${prefix}/lib

    # NVIDIA Performance Primitives Library
    mv lib/libnpp*.*dylib ${prefix}/lib

    # NVIDIA Optimizing Compiler Library
    mv nvvm/lib/libnvvm.*dylib ${prefix}/lib
    mv nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv extras/CUPTI/lib/libcupti.*dylib ${prefix}/lib
    mv extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    mv lib/libnvToolsExt.*dylib ${prefix}/lib

    # CUDA Disassembler
    mv bin/nvdisasm ${prefix}/bin
fi
"""

products = [
    LibraryProduct(["libcudart", "cudart64_100"], :libcudart),
    FileProduct(["lib/libcudadevrt.a", "lib/cudadevrt.lib"], :libcudadevrt),
    LibraryProduct(["libcufft", "cufft64_100"], :libcufft),
    LibraryProduct(["libcufftw", "cufftw64_100"], :libcufftw),
    LibraryProduct(["libcublas", "cublas64_100"], :libcublas),
    LibraryProduct(["libnvblas", "nvblas64_100"], :libnvblas),
    LibraryProduct(["libcusparse", "cusparse64_100"], :libcusparse),
    LibraryProduct(["libcusolver", "cusolver64_100"], :libcusolver),
    LibraryProduct(["libcurand", "curand64_100"], :libcurand),
    LibraryProduct(["libnvgraph", "nvgraph64_100"], :libcurand),
    LibraryProduct(["libnppc", "nppc64_100"], :libnppc),
    LibraryProduct(["libnppial", "nppial64_100"], :libnppial),
    LibraryProduct(["libnppicc", "nppicc64_100"], :libnppicc),
    LibraryProduct(["libnppicom", "nppicom64_100"], :libnppicom),
    LibraryProduct(["libnppidei", "nppidei64_100"], :libnppidei),
    LibraryProduct(["libnppif", "nppif64_100"], :libnppif),
    LibraryProduct(["libnppig", "nppig64_100"], :libnppig),
    LibraryProduct(["libnppim", "nppim64_100"], :libnppim),
    LibraryProduct(["libnppist", "nppist64_100"], :libnppist),
    LibraryProduct(["libnppisu", "nppisu64_100"], :libnppisu),
    LibraryProduct(["libnppitc", "nppitc64_100"], :libnppitc),
    LibraryProduct(["libnpps", "npps64_100"], :libnpps),
    LibraryProduct(["libnvvm", "nvvm64_33_0"], :libnvvm),
    FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
    LibraryProduct(["libcupti", "cupti64_100"], :libcupti),
    LibraryProduct(["libnvToolsExt", "nvToolsExt64_1"], :libnvtoolsext),
    ExecutableProduct("nvdisasm", :nvdisasm),
]

if wants_version(v"10.0")
    if wants_target("x86_64-linux-gnu")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_linux, script, [Linux(:x86_64)], products, dependencies))
    end
    if wants_target(r"x86_64-apple-darwin")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_macos, script, [MacOS(:x86_64)], products, dependencies))
    end
    if wants_target("x86_64-w64-mingw32")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_windows, script, [Windows(:x86_64)], products, dependencies))
    end
end


#
# CUDA 9.2
#

cuda_version = v"9.2.148"
output[cuda_version] = Dict()

sources_linux = [
    "https://developer.nvidia.com/compute/cuda/9.2/Prod2/local_installers/cuda_9.2.148_396.37_linux" =>
    "f5454ec2cfdf6e02979ed2b1ebc18480d5dded2ef2279e9ce68a505056da8611"
]
sources_macos = [
    "https://developer.nvidia.com/compute/cuda/9.2/Prod2/local_installers/cuda_9.2.148_mac" =>
    "defb095aa002301f01b2f41312c9b1630328847800baa1772fe2bbb811d5fa9f"
]
sources_windows = [
    "https://developer.nvidia.com/compute/cuda/9.2/Prod2/local_installers2/cuda_9.2.148_win10" =>
    "7d99a6d135587d029c2cf159ade4e71c02fc1a922a5ffd06238b2bde8bedc362"
]

script = raw"""
cd ${WORKSPACE}/srcdir

# use a temporary directory to avoid running out of tmpfs in srcdir on Travis
temp=${WORKSPACE}/tmpdir
mkdir ${temp}

apk add p7zip

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh *-cuda_*_linux --tmpdir="${temp}" --extract="${temp}"
    cd ${temp}
    sh cuda-linux.*.run --noexec --keep
    cd pkg
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # headers (we copy them all, CUDA on Linux doesn't split in subprojects)
    mv include/* ${prefix}/include
    rm -rf ${prefix}/include/thrust

    # CUDA Runtime
    mv lib64/libcudart.so* lib64/libcudadevrt.a ${prefix}/lib

    # CUDA FFT Library
    mv lib64/libcufft.so* lib64/libcufftw.so* ${prefix}/lib

    # CUDA BLAS Library
    mv lib64/libcublas.so* ${prefix}/lib

    # NVIDIA "Drop-in" BLAS Library
    mv lib64/libnvblas.so* ${prefix}/lib

    # CUDA Sparse Matrix Library
    mv lib64/libcusparse.so* ${prefix}/lib

    # CUDA Linear Solver Library
    mv lib64/libcusolver.so* ${prefix}/lib

    # CUDA Random Number Generation Library
    mv lib64/libcurand.so* ${prefix}/lib

    # CUDA Accelerated Graph Library
    mv lib64/libnvgraph.so* ${prefix}/lib

    # NVIDIA Performance Primitives Library
    mv lib64/libnpp*.so* ${prefix}/lib

    # NVIDIA Optimizing Compiler Library
    mv nvvm/lib64/libnvvm.so* ${prefix}/lib
    mv nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv extras/CUPTI/lib64/libcupti.so* ${prefix}/lib
    mv extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    mv lib64/libnvToolsExt.so* ${prefix}/lib

    # CUDA Disassembler
    mv bin/nvdisasm ${prefix}/bin
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x *-cuda_*_win10 -o${temp}
    cd ${temp}
    7z x "CUDAVisualStudioIntegration/NVIDIA NVTX Installer.x86_64".*.msi -o${temp}/nvtx_installer
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # CUDA Runtime
    mv cudart/bin/cudart64_*.dll ${prefix}/bin
    mv nvcc/lib/x64/cudadevrt.lib ${prefix}/lib
    mv nvcc/include/* ${prefix}/include

    # CUDA FFT Library
    mv cufft/bin/cufft64_*.dll cufft/bin/cufftw64_*.dll ${prefix}/bin
    mv cufft_dev/include/* ${prefix}/include

    # CUDA BLAS Library
    mv cublas/bin/cublas64_*.dll ${prefix}/bin
    mv cublas_dev/include/* ${prefix}/include

    # NVIDIA "Drop-in" BLAS Library
    mv cublas/bin/nvblas64_*.dll ${prefix}/bin

    # CUDA Sparse Matrix Library
    mv cusparse/bin/cusparse64_*.dll ${prefix}/bin
    mv cusparse_dev/include/* ${prefix}/include

    # CUDA Linear Solver Library
    mv cusolver/bin/cusolver64_*.dll ${prefix}/bin
    mv cusolver_dev/include/* ${prefix}/include

    # CUDA Random Number Generation Library
    mv curand/bin/curand64_*.dll ${prefix}/bin
    mv curand_dev/include/* ${prefix}/include

    # CUDA Accelerated Graph Library
    mv nvgraph/bin/nvgraph64_*.dll ${prefix}/bin
    mv nvgraph_dev/include/* ${prefix}/include

    # NVIDIA Performance Primitives Library
    mv npp/bin/npp*64_*.dll ${prefix}/bin
    mv npp_dev/include/* ${prefix}/include

    # NVIDIA Optimizing Compiler Library
    mv nvcc/nvvm/bin/nvvm64_*.dll ${prefix}/bin
    mv nvcc/nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvcc/nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv cupti/extras/CUPTI/libx64/cupti64_*.dll ${prefix}/bin
    mv cupti/extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    for file in nvtx_installer/*.*_*; do
        mv $file $(echo $file | sed 's/\.\(\w*\)_.*/.\1/')
    done
    mv nvtx_installer/nvToolsExt64_1.dll ${prefix}/bin
    mv nvtx_installer/*.h ${prefix}/include

    # CUDA Disassembler
    mv nvdisasm/bin/nvdisasm.exe ${prefix}/bin
    chmod +x ${prefix}/bin/nvdisasm.exe
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x *-cuda_*_mac -o${temp}
    cd ${temp}
    tar -xzf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    cd Developer/NVIDIA/CUDA-*/
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # headers (we copy them all, CUDA on macOS doesn't split in subprojects)
    mv include/* ${prefix}/include
    rm -rf ${prefix}/include/thrust

    # CUDA Runtime
    mv lib/libcudart.*dylib lib/libcudadevrt.a ${prefix}/lib

    # CUDA FFT Library
    mv lib/libcufft.*dylib lib/libcufftw.*dylib ${prefix}/lib

    # CUDA BLAS Library
    mv lib/libcublas.*dylib ${prefix}/lib

    # NVIDIA "Drop-in" BLAS Library
    mv lib/libnvblas.*dylib ${prefix}/lib

    # CUDA Sparse Matrix Library
    mv lib/libcusparse.*dylib ${prefix}/lib

    # CUDA Linear Solver Library
    mv lib/libcusolver.*dylib ${prefix}/lib

    # CUDA Random Number Generation Library
    mv lib/libcurand.*dylib ${prefix}/lib

    # CUDA Accelerated Graph Library
    mv lib/libnvgraph.*dylib ${prefix}/lib

    # NVIDIA Performance Primitives Library
    mv lib/libnpp*.*dylib ${prefix}/lib

    # NVIDIA Optimizing Compiler Library
    mv nvvm/lib/libnvvm.*dylib ${prefix}/lib
    mv nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv extras/CUPTI/lib/libcupti.*dylib ${prefix}/lib
    mv extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    mv lib/libnvToolsExt.*dylib ${prefix}/lib

    # CUDA Disassembler
    mv bin/nvdisasm ${prefix}/bin
fi
"""

products = [
    LibraryProduct(["libcudart", "cudart64_92"], :libcudart),
    FileProduct(["lib/libcudadevrt.a", "lib/cudadevrt.lib"], :libcudadevrt),
    LibraryProduct(["libcufft", "cufft64_92"], :libcufft),
    LibraryProduct(["libcufftw", "cufftw64_92"], :libcufftw),
    LibraryProduct(["libcublas", "cublas64_92"], :libcublas),
    LibraryProduct(["libnvblas", "nvblas64_92"], :libnvblas),
    LibraryProduct(["libcusparse", "cusparse64_92"], :libcusparse),
    LibraryProduct(["libcusolver", "cusolver64_92"], :libcusolver),
    LibraryProduct(["libcurand", "curand64_92"], :libcurand),
    LibraryProduct(["libnvgraph", "nvgraph64_92"], :libcurand),
    LibraryProduct(["libnppc", "nppc64_92"], :libnppc),
    LibraryProduct(["libnppial", "nppial64_92"], :libnppial),
    LibraryProduct(["libnppicc", "nppicc64_92"], :libnppicc),
    LibraryProduct(["libnppicom", "nppicom64_92"], :libnppicom),
    LibraryProduct(["libnppidei", "nppidei64_92"], :libnppidei),
    LibraryProduct(["libnppif", "nppif64_92"], :libnppif),
    LibraryProduct(["libnppig", "nppig64_92"], :libnppig),
    LibraryProduct(["libnppim", "nppim64_92"], :libnppim),
    LibraryProduct(["libnppist", "nppist64_92"], :libnppist),
    LibraryProduct(["libnppisu", "nppisu64_92"], :libnppisu),
    LibraryProduct(["libnppitc", "nppitc64_92"], :libnppitc),
    LibraryProduct(["libnpps", "npps64_92"], :libnpps),
    LibraryProduct(["libnvvm", "nvvm64_32_0"], :libnvvm),
    FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
    LibraryProduct(["libcupti", "cupti64_92"], :libcupti),
    LibraryProduct(["libnvToolsExt", "nvToolsExt64_1"], :libnvtoolsext),
    ExecutableProduct("nvdisasm", :nvdisasm),
]

if wants_version(v"9.2")
    if wants_target("x86_64-linux-gnu")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_linux, script, [Linux(:x86_64)], products, dependencies))
    end
    if wants_target(r"x86_64-apple-darwin")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_macos, script, [MacOS(:x86_64)], products, dependencies))
    end
    if wants_target("x86_64-w64-mingw32")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_windows, script, [Windows(:x86_64)], products, dependencies))
    end
end


#
# CUDA 9.0
#

cuda_version = v"9.0.176"
output[cuda_version] = Dict()

sources_linux = [
    "https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_384.81_linux-run" =>
    "96863423feaa50b5c1c5e1b9ec537ef7ba77576a3986652351ae43e66bcd080c"
]
sources_macos = [
    "https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_mac-dmg" =>
    "8fad950098337d2611d64617ca9f62c319d97c5e882b8368ed196e994bdaf225"
]
sources_windows = [
    "https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda_9.0.176_win10-exe" =>
    "615946c36c415d7d37b22dbade54469f0ed037b1b6470d6b8a108ab585e2621a"
]

script = raw"""
cd ${WORKSPACE}/srcdir

# use a temporary directory to avoid running out of tmpfs in srcdir on Travis
temp=${WORKSPACE}/tmpdir
mkdir ${temp}

apk add p7zip

if [[ ${target} == x86_64-linux-gnu ]]; then
    sh *-cuda_*_linux-run --tmpdir="${temp}" --extract="${temp}"
    cd ${temp}
    sh cuda-linux.*.run --noexec --keep
    cd pkg
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # headers (we copy them all, CUDA on Linux doesn't split in subprojects)
    mv include/* ${prefix}/include
    rm -rf ${prefix}/include/thrust

    # CUDA Runtime
    mv lib64/libcudart.so* lib64/libcudadevrt.a ${prefix}/lib

    # CUDA FFT Library
    mv lib64/libcufft.so* lib64/libcufftw.so* ${prefix}/lib

    # CUDA BLAS Library
    mv lib64/libcublas.so* ${prefix}/lib

    # NVIDIA "Drop-in" BLAS Library
    mv lib64/libnvblas.so* ${prefix}/lib

    # CUDA Sparse Matrix Library
    mv lib64/libcusparse.so* ${prefix}/lib

    # CUDA Linear Solver Library
    mv lib64/libcusolver.so* ${prefix}/lib

    # CUDA Random Number Generation Library
    mv lib64/libcurand.so* ${prefix}/lib

    # CUDA Accelerated Graph Library
    mv lib64/libnvgraph.so* ${prefix}/lib

    # NVIDIA Performance Primitives Library
    mv lib64/libnpp*.so* ${prefix}/lib

    # NVIDIA Optimizing Compiler Library
    mv nvvm/lib64/libnvvm.so* ${prefix}/lib
    mv nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv extras/CUPTI/lib64/libcupti.so* ${prefix}/lib
    mv extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    mv lib64/libnvToolsExt.so* ${prefix}/lib

    # CUDA Disassembler
    mv bin/nvdisasm ${prefix}/bin
elif [[ ${target} == x86_64-w64-mingw32 ]]; then
    7z x *-cuda_*_win10-exe -o${temp}
    cd ${temp}
    7z x "CUDAVisualStudioIntegration/NVIDIA NVTX Installer.x86_64".*.msi -o${temp}/nvtx_installer
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # CUDA Runtime
    mv cudart/bin/cudart64_*.dll ${prefix}/bin
    mv compiler/lib/x64/cudadevrt.lib ${prefix}/lib
    mv compiler/include/* ${prefix}/include

    # CUDA FFT Library
    mv cufft/bin/cufft64_*.dll cufft/bin/cufftw64_*.dll ${prefix}/bin
    mv cufft_dev/include/* ${prefix}/include

    # CUDA BLAS Library
    mv cublas/bin/cublas64_*.dll ${prefix}/bin
    mv cublas_dev/include/* ${prefix}/include

    # NVIDIA "Drop-in" BLAS Library
    mv cublas/bin/nvblas64_*.dll ${prefix}/bin

    # CUDA Sparse Matrix Library
    mv cusparse/bin/cusparse64_*.dll ${prefix}/bin
    mv cusparse_dev/include/* ${prefix}/include

    # CUDA Linear Solver Library
    mv cusolver/bin/cusolver64_*.dll ${prefix}/bin
    mv cusolver_dev/include/* ${prefix}/include

    # CUDA Random Number Generation Library
    mv curand/bin/curand64_*.dll ${prefix}/bin
    mv curand_dev/include/* ${prefix}/include

    # CUDA Accelerated Graph Library
    mv nvgraph/bin/nvgraph64_*.dll ${prefix}/bin
    mv nvgraph_dev/include/* ${prefix}/include

    # NVIDIA Performance Primitives Library
    mv npp/bin/npp*64_*.dll ${prefix}/bin
    mv npp_dev/include/* ${prefix}/include

    # NVIDIA Optimizing Compiler Library
    mv compiler/nvvm/bin/nvvm64_*.dll ${prefix}/bin
    mv compiler/nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv compiler/nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv command_line_tools/extras/CUPTI/libx64/cupti64_*.dll ${prefix}/bin
    mv command_line_tools/extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    for file in nvtx_installer/*.*_*; do
        mv $file $(echo $file | sed 's/\.\(\w*\)_.*/.\1/')
    done
    mv nvtx_installer/nvToolsExt64_1.dll ${prefix}/bin
    mv nvtx_installer/*.h ${prefix}/include

    # CUDA Disassembler
    mv compiler/bin/nvdisasm.exe ${prefix}/bin
    chmod +x ${prefix}/bin/nvdisasm.exe
elif [[ ${target} == x86_64-apple-darwin* ]]; then
    7z x *-cuda_*_mac-dmg -o${temp}
    cd ${temp}
    tar -xzf CUDAMacOSXInstaller/CUDAMacOSXInstaller.app/Contents/Resources/payload/cuda_mac_installer_tk.tar.gz
    cd Developer/NVIDIA/CUDA-*/
    find .

    # prepare
    mkdir ${prefix}/bin ${prefix}/lib ${prefix}/share ${prefix}/include

    # license
    mkdir -p ${prefix}/share/licenses/CUDA
    mv EULA.txt ${prefix}/share/licenses/CUDA/

    # headers (we copy them all, CUDA on macOS doesn't split in subprojects)
    mv include/* ${prefix}/include
    rm -rf ${prefix}/include/thrust

    # CUDA Runtime
    mv lib/libcudart.*dylib lib/libcudadevrt.a ${prefix}/lib

    # CUDA FFT Library
    mv lib/libcufft.*dylib lib/libcufftw.*dylib ${prefix}/lib

    # CUDA BLAS Library
    mv lib/libcublas.*dylib ${prefix}/lib

    # NVIDIA "Drop-in" BLAS Library
    mv lib/libnvblas.*dylib ${prefix}/lib

    # CUDA Sparse Matrix Library
    mv lib/libcusparse.*dylib ${prefix}/lib

    # CUDA Linear Solver Library
    mv lib/libcusolver.*dylib ${prefix}/lib

    # CUDA Random Number Generation Library
    mv lib/libcurand.*dylib ${prefix}/lib

    # CUDA Accelerated Graph Library
    mv lib/libnvgraph.*dylib ${prefix}/lib

    # NVIDIA Performance Primitives Library
    mv lib/libnpp*.*dylib ${prefix}/lib

    # NVIDIA Optimizing Compiler Library
    mv nvvm/lib/libnvvm.*dylib ${prefix}/lib
    mv nvvm/include/* ${prefix}/include

    # NVIDIA Common Device Math Functions Library
    mkdir ${prefix}/share/libdevice
    mv nvvm/libdevice/libdevice.10.bc ${prefix}/share/libdevice

    # CUDA Profiling Tools Interface (CUPTI) Library
    mv extras/CUPTI/lib/libcupti.*dylib ${prefix}/lib
    mv extras/CUPTI/include/* ${prefix}/include

    # NVIDIA Tools Extension Library
    mv lib/libnvToolsExt.*dylib ${prefix}/lib

    # CUDA Disassembler
    mv bin/nvdisasm ${prefix}/bin
fi
"""

products = [
    LibraryProduct(["libcudart", "cudart64_90"], :libcudart),
    FileProduct(["lib/libcudadevrt.a", "lib/cudadevrt.lib"], :libcudadevrt),
    LibraryProduct(["libcufft", "cufft64_90"], :libcufft),
    LibraryProduct(["libcufftw", "cufftw64_90"], :libcufftw),
    LibraryProduct(["libcublas", "cublas64_90"], :libcublas),
    LibraryProduct(["libnvblas", "nvblas64_90"], :libnvblas),
    LibraryProduct(["libcusparse", "cusparse64_90"], :libcusparse),
    LibraryProduct(["libcusolver", "cusolver64_90"], :libcusolver),
    LibraryProduct(["libcurand", "curand64_90"], :libcurand),
    LibraryProduct(["libnvgraph", "nvgraph64_90"], :libcurand),
    LibraryProduct(["libnppc", "nppc64_90"], :libnppc),
    LibraryProduct(["libnppial", "nppial64_90"], :libnppial),
    LibraryProduct(["libnppicc", "nppicc64_90"], :libnppicc),
    LibraryProduct(["libnppicom", "nppicom64_90"], :libnppicom),
    LibraryProduct(["libnppidei", "nppidei64_90"], :libnppidei),
    LibraryProduct(["libnppif", "nppif64_90"], :libnppif),
    LibraryProduct(["libnppig", "nppig64_90"], :libnppig),
    LibraryProduct(["libnppim", "nppim64_90"], :libnppim),
    LibraryProduct(["libnppist", "nppist64_90"], :libnppist),
    LibraryProduct(["libnppisu", "nppisu64_90"], :libnppisu),
    LibraryProduct(["libnppitc", "nppitc64_90"], :libnppitc),
    LibraryProduct(["libnpps", "npps64_90"], :libnpps),
    LibraryProduct(["libnvvm", "nvvm64_32_0"], :libnvvm),
    FileProduct("share/libdevice/libdevice.10.bc", :libdevice),
    LibraryProduct(["libcupti", "cupti64_90"], :libcupti),
    LibraryProduct(["libnvToolsExt", "nvToolsExt64_1"], :libnvtoolsext),
    ExecutableProduct("nvdisasm", :nvdisasm),
]

if wants_version(v"9.0")
    if wants_target("x86_64-linux-gnu")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_linux, script, [Linux(:x86_64)], products, dependencies))
    end
    if wants_target(r"x86_64-apple-darwin")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_macos, script, [MacOS(:x86_64)], products, dependencies))
    end
    if wants_target("x86_64-w64-mingw32")
        merge!(output[cuda_version], build_tarballs(ARGS, name, cuda_version, sources_windows, script, [Windows(:x86_64)], products, dependencies))
    end
end


#
# Generate artifact
#

using Pkg
using Pkg.Artifacts

bin_path = "https://github.com/JuliaGPU/CUDABuilder/releases/download/v$(tag)"
artifacts_toml = joinpath(@__DIR__, "Artifacts.toml")

for cuda_version in keys(output)
    src_name = "CUDA$(cuda_version.major).$(cuda_version.minor)"

    for platform in keys(output[cuda_version])
        tarball_name, tarball_hash, git_hash, products_info = output[cuda_version][platform]

        download_info = Tuple[
            (joinpath(bin_path, basename(tarball_name)), tarball_hash),
        ]
        bind_artifact!(artifacts_toml, src_name, git_hash; platform=platform, download_info=download_info, force=true, lazy=true)
    end
end
