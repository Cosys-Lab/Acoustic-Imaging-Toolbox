function success = compileClaitMexFunctions(enableGPU)

    success = false;

    warning("if you run into errors make sure to run 'mex -setup c++' first to select a compiler!")
    foundPath = clait.findClaitToolboxFolder();
    cd(char(foundPath.toAbsolutePath.toString)); 
    buildtool mex
    
    if enableGPU
        buildtool gpu
    end

    success = true;
end