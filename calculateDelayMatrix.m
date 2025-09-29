function [delayMatrix, errorMatrix] = calculateDelayMatrix(azVec, elVec, micCoordinates, fsAdc)
%CALCULATEDELAYMATRIX Compute sample delays and error per microphone for given directions.
%
%   [delayMatrix, errorMatrix] = CALCULATEDELAYMATRIX(azVec, elVec, ...
%                                                      micCoordinates, fsAdc) 
%   calculates the time-of-arrival sample delays for a planar wave arriving from 
%   specified directions onto a microphone array, and computes the associated 
%   fractional delay errors.
%
%   The delays are calculated relative to the microphone that receives the signal 
%   first (i.e., the minimum delay for each direction is normalized to 0 samples).
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   azVec            : Azimuth angles of the source directions.
%                      Dimensions: [numAngles x 1] or [1 x numAngles]. Units: degrees. (Mandatory)
%
%   elVec            : Elevation angles of the source directions.
%                      Dimensions: [numAngles x 1] or [1 x numAngles]. Units: degrees. (Mandatory)
%
%   micCoordinates   : Microphone positions (spatial coordinates).
%                      Dimensions: [numMics x 3]. Units: meters (m). (Mandatory)
%
%   fsAdc            : ADC sampling frequency.
%                      Dimensions: [1 x 1]. Units: Hertz (Hz). (Mandatory)
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   delayMatrix      : Integer delays (in samples) for beamforming.
%                      Dimensions: [numAngles x numMics].
%
%   errorMatrix      : Fractional delay errors (residual error after rounding 
%                      the delay to an integer sample).
%                      Dimensions: [numAngles x numMics]. Units: seconds (s).
%
%   NOTES:
%   - The speed of sound is fixed internally at c = 343 m/s.
%   - The resulting integer delays in `delayMatrix` are crucial for the 
%     Delay-and-Sum (DAS) or DMAS beamforming algorithms.

    % Convert to radians
    azVecRad = deg2rad(azVec);
    elVecRad = deg2rad(elVec);
    
    numAngles = length(azVec);
    numMics   = size(micCoordinates, 1);
    
    % Convert spherical angles to unit direction vectors
    [xPos, yPos, zPos] = sph2cart(azVecRad, elVecRad, ones(1, numAngles));
    dirCoordinates = [xPos; yPos; zPos]';
    
    % Initialize outputs
    delayMatrix = zeros(numAngles, numMics);
    errorMatrix = zeros(numAngles, numMics);
    
    % Speed of sound [m/s]
    c = 343; 
    
    for angleIdx = 1:numAngles
        curDir = dirCoordinates(angleIdx, :);
        
        % Distances from microphones to plane-wave front direction
        distVec = sqrt( sum( (micCoordinates - repmat(curDir, numMics, 1)).^2, 2 ) );
        distDiffVec = distVec - distVec(1);
        
        % Convert to sample delays
        timeDelayVec = round( distDiffVec / c * fsAdc );
        
        % Fractional delay error (in seconds)
        errorVec = timeDelayVec - (distDiffVec / c * fsAdc);
        errorMatrix(angleIdx, :) = errorVec / fsAdc;
        
        % Normalize to minimum delay = 0
        timeDelayVec = timeDelayVec - min(timeDelayVec);
        delayMatrix(angleIdx, :) = timeDelayVec;
    end
end
