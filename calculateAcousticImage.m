function acousticImage = calculateAcousticImage(dataMicrophones, structSensor, structImage)
%CALCULATEACOUSTICIMAGE Sonar image beamforming using D(M)AS and coherence factors.
%
%   acousticImage = CALCULATEACOUSTICIMAGE(dataMicrophones, structSensor, structImage) 
%   computes a sonar image by first applying matched filtering, calculating the 
%   time delay matrix, and then performing beamforming (DAS/DMAS) with 
%   post-processing steps (envelope detection, thresholding, and decimation).
%
%   All beamforming and post-processing settings are controlled via structImage.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Wouter Jansen & Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   dataMicrophones  : Received signal data. 
%                      Dimensions: (samples x channels). (Mandatory)
%
%   structSensor     : Structure containing sensor array setup and signal characteristics. (Mandatory)
%       .coordinatesMicrophones : Positions of the array elements.  [numMics x 3] (right-handed coordinate system [X Y Z], m)
%       .sampleRate             : ADC sampling frequency. (Hz)
%       .emissionSignal         : The transmitted signal used for matched filtering. [numSamplesBase x 1]
%
%   structImage      : Structure containing image formation parameters, beamforming 
%                      methodology, and post-processing flags. (Optional - Defaulted if empty)
%       .directionsAzimuth      : Vector of azimuth angles of the directions interest for beamforming. [numDirections x 1] (right-handed coordinate system, deg)
%       .directionsElevation    : Vector of elevation angles of the directions interest for beamforming. [numDirections x 1] (right-handed coordinate system, deg)
%       .methodImaging          : Beamforming algorithm. Default: 'DAS'.
%                                 Options: 'DAS', 'DMAS' (DMAS2 is equivalent), 'DMAS3', 'DMAS4', 'DMAS5'.
%       .coherenceType          : Coherence Factor type. Default: 'cf'.
%                                 Options: 'none', 'cf', 'pcf', 'scf'.
%       .methodProcessing       : Execution method. Default: 'mexcpu'.
%                                 Options: 'mexcuda', 'mexcpu', 'native'.
%       .lowpassFreq            : Cutoff frequency for envelope detection LPF. Default: 5e3 (Hz).
%       .matchedFilterMethod:   : String specifying the generalized Matched Filtering. Default: 'Normal'    
%                                 Options: 'Normal', 'PHAT', 'ROTH' , 'SCOT'.
%       .matchedFilterFreq:     : The band in which to perform the matched filter. Default: [20e3 80e3] (Hz)
%       .doMatchedFilter        : Flag (1 or 0) to enable matched filter with the emission signal. Default: 1.
%       .doEnvelope             : Flag (1 or 0) to enable envelope detection. Default: 1.
%       .doThresholdAtZero      : Flag (1 or 0) to clip negative values. Default: 1.
%       .decimationFactor       : Factor N to decimate the final image by. Default: 10.
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   acousticImage       : The computed beamformed and post-processed sonar image.
%                      Dimensions: ([samples/decimationFactor] x numDirections).

    if nargin < 2
        error('calculateAcousticImage:MissingInput', 'At least dataMicrophones and structSensor must be provided.');
    end
    
    if nargin < 3 || isempty(structImage)
        structImage = struct();
    end

    if ~isfield(structImage, 'methodImaging')
        structImage.methodImaging = 'DAS';
    end
    if ~isfield(structImage, 'coherenceType')
        structImage.coherenceType = 'cf';
    end
    if ~isfield(structImage, 'methodProcessing')
        structImage.methodProcessing = 'mexcpu';
    end

    if ~isfield(structImage, 'doMatchedFilter')
        structImage.doMatchedFilter = 1;
    end
    if ~isfield(structImage, 'matchedFilterMethod')
        structImage.matchedFilterMethod = 'Normal';
    end
    if ~isfield(structImage, 'matchedFilterFreq')
        structImage.matchedFilterFreq = [20e3 80e3];
    end

    % Post-processing defaults
    if ~isfield(structImage, 'lowpassFreq')
        structImage.lowpassFreq = 5e3; 
    end
    if ~isfield(structImage, 'doEnvelope')
        structImage.doEnvelope = 1;
    end
    if ~isfield(structImage, 'doThresholdAtZero')
        structImage.doThresholdAtZero = 1;
    end
    if ~isfield(structImage, 'decimationFactor')
        structImage.decimationFactor = 10;
    end
    
    if ~isfield(structImage, 'directionsAzimuth') || ~isfield(structImage, 'directionsElevation')
        error('calculateAcousticImage:MissingImageDirs', 'structImage must contain directionsAzimuth and directionsElevation for delay calculation.');
    end
       
    % 1. Matched Filtering (Uses fixed band [20e3 80e3] and 'Normal' method)
    dataMatchedFiltered = dataMicrophones;
    if( structImage.doMatchedFilter == 1 )
        for cntChannel = 1 : size( structSensor.coordinatesMicrophones, 1 )
            dataMatchedFiltered(:, cntChannel ) = generalizedMatchedFilter( dataMicrophones(:, cntChannel ), structSensor.emissionSignal(:), structImage.matchedFilterMethod, structImage.matchedFilterFreq, structSensor.sampleRate);
        end
    end
    
    % 2. Delay Matrix Calculation
    [ delayMatrix, ~ ] = calculateDelayMatrix( structImage.directionsAzimuth, structImage.directionsElevation, structSensor.coordinatesMicrophones , structSensor.sampleRate );
       
    % 3. Beamforming (DMAS/DAS with CF, using parameters from structImage)
    acousticImage = calculateDMASCF(dataMatchedFiltered, delayMatrix, ...
                                 structImage.methodImaging, ...
                                 structImage.coherenceType, ...
                                 structImage.methodProcessing);
    
    % 4. Post-Processing: Envelope Detection (Low-Pass Filter and Absolute Value)
    if( structImage.doEnvelope == 1 )
        [ bLP, aLP ] = butter( 2, structImage.lowpassFreq / ( structSensor.sampleRate / 2 ) );
        acousticImage = filtfilt( bLP, aLP, abs( acousticImage ) );
    end
    
    % 5. Post-Processing: Thresholding
    if( structImage.doThresholdAtZero == 1 )
        acousticImage( acousticImage<0 ) = 0;
    end
    
    % 6. Post-Processing: Decimation
    acousticImage = acousticImage( 1 : structImage.decimationFactor : end, : );
end