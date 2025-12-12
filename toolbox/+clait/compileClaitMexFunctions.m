function success = compileClaitMexFunctions(enableGPU)

    success = false;

    warning("if you run into errors make sure to run 'mex -setup c++' first to select a compiler!")
    foundPath = clait.findClaitToolboxFolder();
    cd(char(foundPath.toAbsolutePath.toString)); 

    mex "+clait\calculateDMASCFMex.cpp" -outdir "+clait"
    
    if enableGPU
        try
            if ismac
                mexcuda NVCCFLAGS="--allow-unsupported-compiler" -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH "+clait\calculateDMASCFGPU.cu" -output "+clait\calculateDMASCFGPU.mexmaci64" 
            elseif isunix
                mexcuda NVCCFLAGS="--allow-unsupported-compiler" -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH "+clait\calculateDMASCFGPU.cu" -output "+clait\calculateDMASCFGPU.mexa64" 
            elseif ispc
                mexcuda NVCCFLAGS="--allow-unsupported-compiler" -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH "+clait\calculateDMASCFGPU.cu" -output "+clait\calculateDMASCFGPU.mexmw64" 
            else
                disp('Platform not supported')
            end        
        catch exception
            rethrow(exception)
        end
    end

    success = true;
end