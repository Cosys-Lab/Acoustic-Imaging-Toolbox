function acousticImage = calculateDMASCFNative(dataSignals, delayMatrix, orderProcessing, cfType)
%CALCULATEDMASCFNATIVE Sonar image beamforming using D(M)AS and coherence factors.
%
%   acousticImage = CALCULATEDMASCFNATIVE(dataSignals, delayMatrix,
%                 orderProcessing, cfType) computes a
%   sonar image using various beamforming algorithms (DAS, DMAS) with optional
%   Coherence Factor (CF) application, leveraging native MATLAB functions.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   dataSignals      : Received signal data. 
%                      Dimensions: (samples * channels).
%
%   delayMatrix      : Delay indices for beamforming. 
%                      Dimensions: (directions * channels). Integers.
%
%   orderProcessing  : String specifying the beamforming algorithm.
%                      Options: 1=DAS, 2=DMAS, 3=DMAS3, 4=DMAS4, 5=DMAS5
%
%   cfType           : String specifying the Coherence Factor type.
%                      Options: 'none', 'cf' (default), 'pcf', 'scf'.
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   acousticImage       : The computed beamformed sonar image vector.
%                      Dimensions: (samples * directions).

numSamplesSensor = size(dataSignals, 1);
    numDirections = size(delayMatrix, 1);
    acousticImage = zeros(numSamplesSensor, numDirections);

    for cntDirection = 1 : numDirections
        delayVector = delayMatrix(cntDirection, :);
        gainSet = ones(size( delayVector));
        beamformerOutput = calculateDMASCFNativeSingleDirection(dataSignals, delayVector, gainSet, orderProcessing, cfType);
        dataPadded = zeros(numSamplesSensor, 1);
        dataPadded(1 : length( beamformerOutput))= beamformerOutput;
        acousticImage(:, cntDirection) = dataPadded;
    end
end