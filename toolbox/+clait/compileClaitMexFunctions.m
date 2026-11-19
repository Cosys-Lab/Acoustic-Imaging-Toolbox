function success = compileClaitMexFunctions(~)
%COMPILECLAITMEXFUNCTIONS Compile the CPU MEX file of the toolbox.
%
%   success = COMPILECLAITMEXFUNCTIONS() compiles calculateDMASCFMex.cpp.
%   Any compiler supported by MEX works, for example the free MinGW-w64
%   add-on on Windows. Select it with 'mex -setup c++'.
%
%   GPU acceleration ('mexcuda') needs no compiling: it uses the precompiled
%   CUDA kernel calculateDMASCFKernel.ptx. The old enableGPU input is still
%   accepted for backward compatibility, but ignored.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Wouter Jansen, Jan Steckel

    folder = fileparts(mfilename("fullpath"));
    mex(fullfile(folder, "calculateDMASCFMex.cpp"), "-outdir", folder);
    success = true;
end
