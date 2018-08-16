using CUDAapi

config_path = joinpath(@__DIR__, "ext.jl")
const previous_config_path = config_path * ".bak"

function write_ext(config)
    open(config_path, "w") do io
        println(io, "# autogenerated file, do not edit")
        for (key,val) in config
            println(io, "const $key = $(repr(val))")
        end
    end
end

function main()
    ispath(config_path) && mv(config_path, previous_config_path; force=true)
    config = Dict{Symbol,Any}(:configured => false)
    write_ext(config)


    ## discover stuff
    toolkit_dirs = CUDAapi.find_toolkit()

    config[:libnvtx] = CUDAapi.find_cuda_library("nvToolsExt", toolkit_dirs)
    if config[:libnvtx] == nothing
        error("could not find NVTX")
    end

    ## (re)generate ext.jl

    function globals(mod)
        all_names = names(mod, all=true)
        filter(name-> !any(name .== [nameof(mod), Symbol("#eval"), :eval]), all_names)
    end

    if isfile(previous_config_path)
        @debug("Checking validity of existing ext.jl...")
        @eval module Previous; include($previous_config_path); end
        previous_config = Dict{Symbol,Any}(name => getfield(Previous, name)
                                           for name in globals(Previous))

        if config == previous_config
            info("CuArrays.jl has already been built for this toolchain, no need to rebuild")
            mv(previous_config_path, config_path; remove_destination=true)
            return
        end
    end

    config[:configured] = true
    write_ext(config)

    return
end

main()
