function dataMicrophones = simulatePassiveMicrophoneData(structScene, structSensor)
%SIMULATEPASSIVEMICROPHONEDATA Simulates microphone data from broadband sound sources.
%
%   dataMicrophones = SIMULATEPASSIVEMICROPHONEDATA(structScene, structSensor)
%   generates the signals of a microphone array listening to sound sources
%   that emit independent band-limited noise, for example gas leaks or
%   machinery, for passive imaging with calculatePassiveAcousticImage. Every
%   source is delayed exactly (fractional delays in the frequency domain) to
%   every microphone, and independent sensor noise can be added.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Wouter Jansen
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   structScene      : Structure containing the sound sources. (Mandatory)
%       .sourceAzimuth      : Azimuth angles of the sources. [1 x numSources] (deg)
%       .sourceElevation    : Elevation angles of the sources. [1 x numSources] (deg)
%       .sourceRange        : Distance to each source. Inf = far field (plane waves).
%                             [1 x numSources] (m). Default: Inf.
%       .sourceStrength     : RMS amplitude of each source. [1 x numSources]. Default: 1.
%       .sourceBand         : [minFrequency maxFrequency] of the emitted noise (Hz).
%                             Default: [20e3 80e3].
%       .noiseLevel         : RMS amplitude of independent noise on every microphone. Default: 0.
%       .speedOfSound       : Speed of sound in the medium. Default: 343 (m/s).
%
%   structSensor     : Structure containing sensor array setup. (Mandatory)
%       .coordinatesMicrophones : Positions of the microphones. [numMics x 3] (m)
%       .numSamplesSensor       : Number of samples to simulate.
%       .sampleRate             : ADC sampling frequency. (Hz)
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   dataMicrophones  : The simulated microphone data. [numSamplesSensor x numMics]
%
%   NOTES:
%   - The delays are applied as a circular shift of stationary noise, which keeps
%     the exact delay between microphones without edge effects.

    numSources = numel(structScene.sourceAzimuth);
    sourceRange = getField(structScene, 'sourceRange', Inf(1, numSources));
    sourceStrength = getField(structScene, 'sourceStrength', ones(1, numSources));
    sourceBand = getField(structScene, 'sourceBand', [20e3 80e3]);
    noiseLevel = getField(structScene, 'noiseLevel', 0);
    c = getField(structScene, 'speedOfSound', 343);
    if isscalar(sourceRange)
        sourceRange = sourceRange * ones(1, numSources);
    end
    if isscalar(sourceStrength)
        sourceStrength = sourceStrength * ones(1, numSources);
    end

    numSamples = structSensor.numSamplesSensor;
    fs = structSensor.sampleRate;
    microphones = structSensor.coordinatesMicrophones;
    numMics = size(microphones, 1);

    % Signed frequency of every FFT bin, and the band of the emitted noise
    frequencies = (0:numSamples-1)' * fs / numSamples;
    frequencies(frequencies >= fs/2) = frequencies(frequencies >= fs/2) - fs;
    inBand = abs(frequencies) >= sourceBand(1) & abs(frequencies) <= sourceBand(2);

    dataMicrophones = zeros(numSamples, numMics);
    for cntSource = 1:numSources
        % Band-limited noise with the requested RMS amplitude
        spectrum = fft(randn(numSamples, 1)) .* inBand;
        spectrum = spectrum / rms(real(ifft(spectrum))) * sourceStrength(cntSource);

        % Arrival time at every microphone relative to the array origin
        [ux, uy, uz] = sph2cart(deg2rad(structScene.sourceAzimuth(cntSource)), deg2rad(structScene.sourceElevation(cntSource)), 1);
        direction = [ux uy uz];
        if isinf(sourceRange(cntSource))
            delays = -(microphones * direction') / c;
        else
            sourcePosition = sourceRange(cntSource) * direction;
            delays = (vecnorm(microphones - sourcePosition, 2, 2) - sourceRange(cntSource)) / c;
        end

        % Fractional delays as linear phase
        dataMicrophones = dataMicrophones + real(ifft(spectrum .* exp(-1j * 2 * pi * frequencies * delays')));
    end
    dataMicrophones = dataMicrophones + noiseLevel * randn(numSamples, numMics);
end

function value = getField(structure, name, default)
    if isfield(structure, name) && ~isempty(structure.(name))
        value = structure.(name);
    else
        value = default;
    end
end
