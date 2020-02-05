#!/usr/bin/env Julia

using BinaryBuilder
import SHA: sha256

const tag = v"0.1.4"
const bin_prefix = "https://github.com/JuliaGPU/CUDABuilder/releases/download/v$tag"

const platforms = [Linux(:x86_64, libc=:glibc) => "x86_64-linux-gnu",
                   Windows(:x86_64)            => "x86_64-w64-mingw32",
                   MacOS(:x86_64)              => "x86_64-apple-darwin14"]
const cuda_versions = [v"10.2.89", v"10.1.243", v"10.0.130", v"9.2.148", v"9.0.176"]
const cudnn_version = v"7.6.5"

function filehash(path)
    open(path, "r") do f
        bytes2hex(sha256(f))
    end
end

function print_resources(resources)
    println("const bin_prefix = ", repr(bin_prefix))
    println("const resources = Dict(")
    for version in sort(collect(keys(resources)))
        sources = resources[version]
        println("    v\"$(version.major).$(version.minor)\" =>")
        println("        Dict(")
        for (target, (file,hash)) in sources
            println("            ", repr(target), " => ", "(\"\$bin_prefix/$file\", \"$hash\"),")
        end
        println("        ),")
    end
    println(")")
end

function main()
    cuda_resources = Dict()
    cudnn_resources = Dict()
    cd(joinpath(@__DIR__, "products")) do
        for cuda_version in cuda_versions
            cuda_sources = Dict()
            cudnn_sources = Dict()
            for (target, triple) in platforms
                let version = VersionNumber("$(cuda_version)-$(tag)")
                    file = "CUDA.v$(version).$(triple).tar.gz"
                    if isfile(file)
                        println(file)
                        hash = filehash(file)
                        cuda_sources[target] = (file, hash)
                    end
                end

                let version = VersionNumber("$(cudnn_version)-CUDA$(cuda_version.major).$(cuda_version.minor)-$(tag)")
                    file = "CUDNN.v$(version).$(triple).tar.gz"
                    if isfile(file)
                        println(file)
                        hash = filehash(file)
                        cudnn_sources[target] = (file, hash)
                    end
                end
            end
            cuda_resources[cuda_version] = cuda_sources
            cudnn_resources[cuda_version] = cudnn_sources
        end
    end

    println("# CUDAnative.jl")
    print_resources(cuda_resources)

    println()

    println("# CuArrays.jl")
    print_resources(cudnn_resources)
end

cd("products") do
    main()
end
