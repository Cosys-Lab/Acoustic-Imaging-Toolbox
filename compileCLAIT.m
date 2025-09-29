function success = compileCLAIT(enableCPU, enableGPU)
    %% CPU
    warning("if you run into errors make sure to run 'mex -setup c++' first to select a compiler!")
    foundPath = findCLAITFolder();
    cd(char(foundPath.toAbsolutePath.toString));
    success = false;
    
    if enableCPU
        mex calculateDMASCFMexCPU.cpp
    end
    
    %% GPU
    
    if enableGPU
        mexcuda calculateDMASCFMexGPU.cu
    end

    success = true;
end