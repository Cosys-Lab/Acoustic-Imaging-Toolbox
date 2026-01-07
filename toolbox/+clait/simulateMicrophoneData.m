function dataMicrophonesOut = simulateMicrophoneData( structScene, structSensor )
%SIMULATEMICROPHONEDATA Simulates microphone data from point targets in a scene.
%
%   dataMicrophonesOut = SIMULATEMICROPHONEDATA(structScene, structSensor) 
%   generates a time-domain signal for each microphone by simulating the 
%   reflection of an emitted signal from a set of point targets. The simulation 
%   accounts for the time-of-flight from the emitter to each target and then 
%   to each microphone.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   structScene      : Structure containing scene and target properties. (Mandatory)
%       .targetAzimuth      : Azimuth angles of point targets. [numTargets x 1] (deg)
%       .targetElevation    : Elevation angles of point targets. [numTargets x 1] (deg)
%       .targetRange        : Range (distance) to each point target. [numTargets x 1] (m)
%       .speedOfSound       : Speed of sound in the medium. [1 x 1] (m/s)
%       .targetStrength     : Amplitude of the reflection from each target. [numTargets x 1]
%
%   structSensor     : Structure containing sensor array setup and signal characteristics. (Mandatory)
%       .coordinatesEmitter     : Position of the sound source. [1 x 3] (m)
%       .coordinatesMicrophones : Positions of the microphone array elements. [numMics x 3] (m)
%       .numSamplesSensor       : Total number of samples to simulate. [1 x 1]
%       .sampleRate             : ADC sampling frequency. [1 x 1] (Hz)
%       .emissionSignal         : The transmitted signal. [numSamplesBase x 1]
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   dataMicrophonesOut : The simulated microphone data.
%                        Dimensions: [numSamplesSensor x numMics].
%
%   NOTES:
%   - The function models reflections as simple time-of-flight delays and amplitude scaling.
%   - The final output is the convolution of the time-of-flight impulse response with the emission signal.
  
    [ pointsX, pointsY, pointsZ ] = sph2cart( deg2rad( structScene.targetAzimuth ), deg2rad( structScene.targetElevation ), structScene.targetRange  );
    targetsCartesian = [ pointsX ;pointsY ;pointsZ ]';
    
    numTargets = length( structScene.targetAzimuth );
    numChannels = size( structSensor.coordinatesMicrophones, 1 );
    
    dataMicrophones = zeros( structSensor.numSamplesSensor, numChannels );  
    for cntTarget = 1 : numTargets
        rangesToTarget = sqrt( sum(( structSensor.coordinatesEmitter - targetsCartesian( cntTarget, : ) ).^2, 2 ) );
        rangesFromTarget = sqrt( sum(( structSensor.coordinatesMicrophones - targetsCartesian( cntTarget, : ) ).^2, 2 ) );
        totalRanges = rangesToTarget + rangesFromTarget;
        totalTimeInSamples = round( totalRanges / structScene.speedOfSound *  structSensor.sampleRate );
    
        % rows = totalTimeInSamples(:);        % arrival times
        % cols = (1:numChannels)';             % channel indices
        % idx  = sub2ind(size(dataMicrophones), rows, cols);
    
        for cntChannel = 1 : numChannels
            curSample = totalTimeInSamples( cntChannel );
            dataMicrophones( curSample, cntChannel ) = dataMicrophones( curSample, cntChannel ) + structScene.targetStrength( cntTarget );
        end
    end
    dataMicrophonesOut = zeros( size( dataMicrophones ) );
    for cntChannel = 1 : numChannels
        dataMicrophonesOut( :, cntChannel ) = dataMicrophones( :, cntChannel ) + conv( dataMicrophones( :, cntChannel ), structSensor.emissionSignal, 'same' );
    end

end