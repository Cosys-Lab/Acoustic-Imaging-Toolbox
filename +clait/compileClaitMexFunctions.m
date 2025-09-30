function success = compileClaitMexFunctions(enableCPU, enableGPU)

    success = false;

    warning("if you run into errors make sure to run 'mex -setup c++' first to select a compiler!")
    foundPath = clait.findClaitToolboxFolder();
    cd(char(foundPath.toAbsolutePath.toString));
    cd +clait   
    if enableCPU
        mex calculateDMASCFMexCPU.cpp
    end
    
    if enableGPU
        mexcuda calculateDMASCFMexGPU.cu
    end

    success = true;
end