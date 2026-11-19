function acousticImage = calculateDMASCFCUDAKernel(dataSignals, delayMatrix, orderProcessing, toggleCF)
%CALCULATEDMASCFCUDAKERNEL GPU DMAS-CF beamforming using the precompiled PTX kernel.
%
%   acousticImage = CALCULATEDMASCFCUDAKERNEL(dataSignals, delayMatrix,
%                   orderProcessing, toggleCF) runs the DMAS-CF CUDA kernel
%   from calculateDMASCFKernel.ptx through parallel.gpu.CUDAKernel. This needs
%   no CUDA toolkit or C++ compiler: only Parallel Computing Toolbox and an
%   NVIDIA GPU with a driver.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Wouter Jansen, Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   dataSignals      : Received signal data (CPU array or gpuArray).
%                      Dimensions: (samples * channels).
%
%   delayMatrix      : Delay indices for beamforming.
%                      Dimensions: (directions * channels). Integers.
%
%   orderProcessing  : 1=DAS, 2=DMAS, 3=DMAS3, 4=DMAS4, 5=DMAS5.
%
%   toggleCF         : 0 = no coherence factor, 1 = coherence factor.
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   acousticImage    : Beamformed image as a single gpuArray.
%                      Dimensions: ((samples + 4*maxDelay) * directions).
%                      Only the first (samples - 2*maxDelay) rows are filled,
%                      the same as the MEX implementations.
%
%   NOTES:
%   - The PTX is regenerated from calculateDMASCFKernel.cu by the "ptx" task in
%     buildfile.m. Users never need to compile it.

    % Max delay on the CPU when possible, to avoid a GPU sync.
    maxDelay = max(0, double(gather(max(delayMatrix, [], "all"))));

    dataSignals = gpuArray(single(dataSignals));
    delayMatrix = gpuArray(int32(delayMatrix));

    nSamples = size(dataSignals, 1);
    nMicrophones = size(dataSignals, 2);
    nDirections = size(delayMatrix, 1);
    outputSize = nSamples + 4 * maxDelay;
    sampleSize = nSamples - 2 * maxDelay;

    acousticImage = zeros(outputSize, nDirections, "single", "gpuArray");
    if sampleSize <= 0 || nDirections == 0
        return
    end

    gridSize = [ceil(sampleSize / 64), ceil(nDirections / 4)];
    try
        kernel = getKernel(false);
        kernel.GridSize = gridSize;
    catch
        % The cached kernel is invalid after a GPU reset or device change.
        kernel = getKernel(true);
        kernel.GridSize = gridSize;
    end

    % Signed n-th roots sgn(x)*|x|^(1/n), computed once per sample here instead
    % of once per direction inside the kernel. DAS does not use them.
    if orderProcessing >= 2
        rootSignals = sign(dataSignals) .* abs(dataSignals) .^ (1 / double(orderProcessing));
    else
        rootSignals = dataSignals;
    end

    acousticImage = feval(kernel, delayMatrix, dataSignals, rootSignals, acousticImage, ...
        nMicrophones, nDirections, nSamples, outputSize, sampleSize, ...
        int32(orderProcessing), int32(toggleCF));
end

function kernel = getKernel(reload)
    % Load the kernel once and reuse it.
    persistent cachedKernel
    if isempty(cachedKernel) || reload
        folder = fileparts(mfilename("fullpath"));
        cachedKernel = parallel.gpu.CUDAKernel( ...
            fullfile(folder, "calculateDMASCFKernel.ptx"), ...
            "const int *, const float *, const float *, float *, int, int, int, int, int, int, int", ...
            "dmascf_kernel");
        cachedKernel.ThreadBlockSize = [64 4 1];
    end
    kernel = cachedKernel;
end
