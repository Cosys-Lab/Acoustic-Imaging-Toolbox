function acousticImage = calculateDMASCF(dataSignals, delayMatrix, methodImaging, coherenceType, methodProcessing)
%CALCULATEDMASCF Sonar image beamforming using D(M)AS and coherence factors.
%
%   acousticImage = CALCULATEDMASCF(dataSignals, delayMatrix, methodImaging, ...
%                                coherenceType, methodProcessing) computes a
%   sonar image using various beamforming algorithms (DAS, DMAS) with optional
%   Coherence Factor (CF) application, leveraging native MATLAB, MEX-CPU, or
%   MEX-GPU acceleration.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Wouter Jansen & Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   dataSignals      : Received signal data. 
%                      Dimensions: (samples * channels).
%
%   delayMatrix      : Delay indices for beamforming. 
%                      Dimensions: (directions * channels). Integers.
%
%   methodImaging    : String specifying the beamforming algorithm.
%                      Options: 'DAS', 'DMAS' (DMAS2 is equivalent), 'DMAS3', 
%                               'DMAS4', 'DMAS5'. Default is 'DAS'.
%
%   coherenceType    : String specifying the Coherence Factor type.
%                      Options: 'none', 'cf' (default), 'pcf', 'scf'.
%                      NOTE: Only 'none' and 'cf' are supported by MEX functions.
%
%   methodProcessing : String specifying the execution method.
%                      Options: 'mexcuda' (GPU acceleration), 
%                               'mexcpu' (CPU acceleration, default), 
%                               'native' (pure MATLAB).
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   acousticImage       : The computed beamformed sonar image vector.
%                      Dimensions: (samples * directions).
%
%   NOTES:
%   - If 'mexcuda' or 'mexcpu' is selected, but the corresponding MEX file 
%     fails to execute, the function attempts to fall back to the next 
%     available method (e.g., MEX-GPU -> MEX-CPU -> Native).
%   - For MEX-accelerated versions, if 'pcf' or 'scf' is specified, a warning 
%     is issued and 'cf' is used instead, as other CF types are not supported.

    defaultMethodImaging = 'DAS';
    defaultCoherenceType = 'cf';
    defaultMethodProcessing = 'mexcpu';

    if nargin < 3
        methodImaging = defaultMethodImaging;
    end
    
    if nargin < 4
        coherenceType = defaultCoherenceType;
    end
    
    if nargin < 5
        methodProcessing = defaultMethodProcessing;
    end

    switch lower(methodProcessing)
        case 'mexcuda'
            enableMex = 1;
            enableGPU = 1;
        case 'mexcpu'
            enableMex = 1;
            enableGPU = 0;
        case 'native'
            enableMex = 0;
            enableGPU = 0;         
        otherwise
            warning('Processing method not supported: %s. Using native Matlab version.', methodProcessing);
            enableMex = 0;
            enableGPU = 0;
    end

    switch lower(methodImaging)
        case 'das'
            orderProcessing = 1;
        case 'dmas'
            orderProcessing = 2;
        case 'dmas2'
            orderProcessing = 2;
        case 'dmas3'
            orderProcessing = 3;
        case 'dmas4'
            orderProcessing = 4;
        case 'dmas5'
            orderProcessing = 5;          
        otherwise
            error('Imaging method not supported: %s', methodImaging);
    end

    if(enableMex)
        switch lower(coherenceType)
            case 'none'
                toggleCF = int32(0);            
            case 'cf'
                toggleCF = int32(1); 
            case 'pcf'
                toggleCF = int32(1);
                warning("PCF is not supported by MEX versions of calculateDMASCF! using normal CF instead.");
            case 'scf'
                toggleCF = int32(1); 
                warning("SCF is not supported by MEX versions of calculateDMASCF! using normal CF instead.");
            otherwise
                error('Coherence Factor type not supported: %s', coherenceType);
        end

        if(enableGPU)
            try
                acousticImage = gather(calculateDMASCFMexGPU(single(dataSignals), int32(delayMatrix), int32(orderProcessing), int32(toggleCF)));
            catch ME
                warning("Could not run calculateDMASCF with MEX CUDA acceleration. Running with normal CPU MEX function. Did you run compileCLAIT(enableCPUCompile, enableGPUCompile) yet? Original error: ")
                disp( getReport( ME, 'extended', 'hyperlinks', 'on' ) )
                try
                    acousticImage = calculateDMASCFMexCPU(dataSignals, delayMatrix, int32(orderProcessing), int32(toggleCF));
                catch ME
                     warning("Could not run calculateDMASCF with MEX acceleration. Running with native Matlab function. Did you run compileCLAIT(enableCPUCompile, enableGPUCompile) yet?  Original error: ")
                     disp( getReport( ME, 'extended', 'hyperlinks', 'on' ) )
                     acousticImage = calculateDMASCFNative(dataSignals, delayMatrix, orderProcessing, coherenceType);
                end
            end
        else
            try
                acousticImage = calculateDMASCFMexCPU(dataSignals, delayMatrix, int32(orderProcessing), int32(toggleCF));
            catch ME
                 warning("Could not run calculateDMASCF with MEX acceleration. Running with native Matlab function. Did you run compileCLAIT(enableCPUCompile, enableGPUCompile) yet? Original error: ")
                 disp( getReport( ME, 'extended', 'hyperlinks', 'on' ) )
                 acousticImage = calculateDMASCFNative(dataSignals, delayMatrix, orderProcessing, coherenceType);
            end
        end
    else
        acousticImage = calculateDMASCFNative(dataSignals, delayMatrix, orderProcessing, coherenceType);
    end
end