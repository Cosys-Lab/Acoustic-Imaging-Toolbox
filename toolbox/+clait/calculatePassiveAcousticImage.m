function [powerMap, powerPerFrequency, frequencies] = calculatePassiveAcousticImage(dataMicrophones, structSensor, structImage)
%CALCULATEPASSIVEACOUSTICIMAGE Passive broadband acoustic image with MVDR (Capon), robust Capon or DAS beamforming.
%
%   [powerMap, powerPerFrequency, frequencies] = CALCULATEPASSIVEACOUSTICIMAGE(dataMicrophones,
%   structSensor, structImage) estimates the power arriving from every direction
%   for sound sources that emit themselves (passive measurements, no emission
%   signal or range), such as gas leaks or machinery. It uses frequency-domain
%   beamforming on the cross-spectral matrix of the microphone signals:
%
%   1. The signals are split in overlapping Hann-windowed snapshots and Fourier
%      transformed. Per frequency bin f the cross-spectral (covariance) matrix
%      R(f) is the average of the snapshot outer products (Welch averaging).
%   2. For every direction the steering vector a(f) holds the exact (fractional)
%      phase delays of a plane wave (or, with focusRange, a point source) to
%      every microphone.
%   3. MVDR / Capon:  P(f) = 1 / (a' R^-1 a), the output power of the filter that
%      passes the steered direction undistorted and minimizes everything else
%      [Capon 1969]. R is diagonally loaded with diagonalLoading times the average
%      microphone power for robustness against estimation errors and steering
%      mismatch [Carlson 1988, Cox et al. 1987].
%      RCB / robust Capon: MVDR that allows the true steering vector to differ from
%      the assumed one by ||e||^2 <= steeringUncertainty * M. This is diagonal loading
%      with the amount computed per direction and frequency [Li, Stoica, Wang 2003].
%      MVDR suppresses a strong source as soon as no direction lies exactly on it
%      (already at 0.5 degree), which makes its source levels unreliable. RCB keeps
%      the levels right and the low background of adaptive beamforming, at the cost
%      of some resolution and computation.
%      DAS / Bartlett: P(f) = a' R a / M^2, the conventional beamformer.
%      All give the power of a single source in its direction (plus noise / M).
%   4. The narrowband maps are averaged over the frequency band (incoherent
%      broadband averaging, see the review of Merino-Martinez et al. 2019).
%
%   GPU ('mexcuda') and CPU ('mexcpu') processing solve all frequencies and
%   directions at once with batched linear algebra (pagemldivide / pagemtimes),
%   so no compiler is needed. 'native' is a straightforward loop version.
%   RCB is much faster on the GPU than on the CPU.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Wouter Jansen
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   dataMicrophones  : Recorded signals. [numSamples x numMics] (Mandatory)
%
%   structSensor     : Structure containing the sensor array setup. (Mandatory)
%       .coordinatesMicrophones : Positions of the microphones. [numMics x 3] (right-handed coordinate system [X Y Z], m)
%       .sampleRate             : ADC sampling frequency. (Hz)
%       .speedOfSound           : Speed of sound. Default: 343 (m/s).
%
%   structImage      : Structure containing the imaging parameters. (Mandatory)
%       .directionsAzimuth   : Azimuth angles to image. [1 x numDirections] (deg)
%       .directionsElevation : Elevation angles to image. [1 x numDirections] (deg)
%       .methodImaging       : 'MVDR' (Capon, highest resolution), 'RCB' (robust Capon, reliable
%                              source levels and lowest background) or 'DAS' (conventional). Default: 'MVDR'.
%       .methodProcessing    : 'mexcuda' (NVIDIA GPU), 'mexcpu' (CPU) or 'native'. Default: 'mexcpu'.
%       .frequencyRange      : [minFrequency maxFrequency] to use (Hz). Default: [20e3 80e3].
%       .fftLength           : Snapshot length in samples. Default: 512.
%       .fftOverlap          : Overlap of the snapshots, 0 to <1. Default: 0.5.
%       .diagonalLoading     : MVDR diagonal loading relative to the average microphone
%                              power, trace(R)/numMics. Default: 0.01.
%       .steeringUncertainty : RCB size of the steering vector uncertainty sphere, relative to
%                              numMics (0 to 1). Larger is more robust, smaller gives more
%                              resolution. Default: 0.05.
%       .focusRange          : Range of the focus point (m), Inf = far field (plane waves). Default: Inf.
%       .removeDiagonal      : DAS only: remove the auto-spectra (diagonal of R) to suppress
%                              uncorrelated microphone noise. Default: false.
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   powerMap          : Broadband power per direction (mean over frequency). [1 x numDirections]
%                       Plot with plotSphericalEnergyscape using options.valueType = 'power'.
%   powerPerFrequency : Power per frequency bin and direction. [numFrequencies x numDirections]
%   frequencies       : Frequency of every bin. [numFrequencies x 1] (Hz)
%
%   NOTES:
%   - MVDR needs a well estimated R: at least as many snapshots as microphones, and
%     about twice as many for less than 3 dB loss [Reed et al. 1974]. A warning is given
%     otherwise; record longer or use a shorter fftLength.
%   - Uncorrelated sources are assumed. Coherent sources (e.g. reflections of the same
%     source) partially cancel in MVDR.
%
%   REFERENCES:
%   - J. Capon, "High-resolution frequency-wavenumber spectrum analysis," Proc. IEEE,
%     vol. 57, no. 8, pp. 1408-1418, 1969.
%   - B. D. Carlson, "Covariance matrix estimation errors and diagonal loading in adaptive
%     arrays," IEEE Trans. Aerosp. Electron. Syst., vol. 24, no. 4, pp. 397-401, 1988.
%   - H. Cox, R. M. Zeskind, M. M. Owen, "Robust adaptive beamforming," IEEE Trans. Acoust.,
%     Speech, Signal Process., vol. 35, no. 10, pp. 1365-1376, 1987.
%   - J. Li, P. Stoica, Z. Wang, "On robust Capon beamforming and diagonal loading," IEEE Trans.
%     Signal Process., vol. 51, no. 7, pp. 1702-1715, 2003.
%   - I. S. Reed, J. D. Mallett, L. E. Brennan, "Rapid convergence rate in adaptive arrays,"
%     IEEE Trans. Aerosp. Electron. Syst., vol. AES-10, no. 6, pp. 853-863, 1974.
%   - R. Merino-Martinez et al., "A review of acoustic imaging methods using phased
%     microphone arrays," CEAS Aeronaut. J., vol. 10, no. 1, pp. 197-230, 2019.

    if nargin < 3
        error('calculatePassiveAcousticImage requires dataMicrophones, structSensor and structImage.');
    end
    opts = getSettings(structSensor, structImage);

    microphones = structSensor.coordinatesMicrophones;
    numMics = size(microphones, 1);
    if size(dataMicrophones, 2) ~= numMics
        error('dataMicrophones has %d channels but structSensor has %d microphones.', size(dataMicrophones, 2), numMics);
    end

    % Frequency bins in the band
    fs = structSensor.sampleRate;
    binFrequencies = (0:opts.fftLength-1)' * fs / opts.fftLength;
    bins = find(binFrequencies >= opts.frequencyRange(1) & binFrequencies <= opts.frequencyRange(2) & binFrequencies < fs/2);
    if isempty(bins)
        error('No frequency bins between %g and %g Hz with fftLength %d.', opts.frequencyRange(1), opts.frequencyRange(2), opts.fftLength);
    end
    frequencies = binFrequencies(bins);

    % Snapshots
    hop = max(1, round(opts.fftLength * (1 - opts.fftOverlap)));
    numSnapshots = floor((size(dataMicrophones, 1) - opts.fftLength) / hop) + 1;
    if numSnapshots < 1
        error('The recording (%d samples) is shorter than fftLength (%d).', size(dataMicrophones, 1), opts.fftLength);
    end
    if ~strcmpi(opts.methodImaging, 'das') && numSnapshots < 2 * numMics
        warning('clait:calculatePassiveAcousticImage:fewSnapshots', ...
            ['Only %d snapshots for %d microphones. MVDR needs at least %d (about %d for less than 3 dB loss), ', ...
             'so its resolution suffers. Record longer or use a shorter fftLength.'], numSnapshots, numMics, numMics, 2 * numMics);
    end

    delays = steeringDelays(microphones, structImage.directionsAzimuth(:)', structImage.directionsElevation(:)', opts);

    switch lower(opts.methodProcessing)
        case {'mexcuda', 'gpu'}
            try
                powerPerFrequency = gather(vectorizedBeamformer(gpuArray(single(dataMicrophones)), ...
                    gpuArray(single(delays)), gpuArray(single(frequencies)), bins, hop, numSnapshots, opts));
            catch ME
                warning('clait:calculatePassiveAcousticImage:gpuFailed', ...
                    'Could not run on the GPU, running on the CPU instead. Original error: %s', ME.message);
                powerPerFrequency = vectorizedBeamformer(double(dataMicrophones), delays, frequencies, bins, hop, numSnapshots, opts);
            end
        case {'mexcpu', 'cpu'}
            powerPerFrequency = vectorizedBeamformer(double(dataMicrophones), delays, frequencies, bins, hop, numSnapshots, opts);
        case 'native'
            powerPerFrequency = nativeBeamformer(double(dataMicrophones), delays, frequencies, bins, hop, numSnapshots, opts);
        otherwise
            error('Processing method not supported: %s', opts.methodProcessing);
    end
    powerPerFrequency = double(powerPerFrequency);
    powerMap = mean(powerPerFrequency, 1);
end

%% Settings with defaults
function opts = getSettings(structSensor, structImage)
    opts.methodImaging = getField(structImage, 'methodImaging', 'MVDR');
    opts.methodProcessing = getField(structImage, 'methodProcessing', 'mexcpu');
    opts.frequencyRange = getField(structImage, 'frequencyRange', [20e3 80e3]);
    opts.fftLength = getField(structImage, 'fftLength', 512);
    opts.fftOverlap = getField(structImage, 'fftOverlap', 0.5);
    opts.diagonalLoading = getField(structImage, 'diagonalLoading', 0.01);
    opts.steeringUncertainty = getField(structImage, 'steeringUncertainty', 0.05);
    opts.focusRange = getField(structImage, 'focusRange', Inf);
    opts.removeDiagonal = getField(structImage, 'removeDiagonal', false);
    opts.speedOfSound = getField(structSensor, 'speedOfSound', 343);
    if ~any(strcmpi(opts.methodImaging, {'mvdr', 'rcb', 'das'}))
        error('Imaging method not supported: %s. Options: ''MVDR'', ''RCB'', ''DAS''.', opts.methodImaging);
    end
    if opts.removeDiagonal && ~strcmpi(opts.methodImaging, 'das')
        error('removeDiagonal is only supported for DAS, MVDR and RCB need the full matrix.');
    end
    if strcmpi(opts.methodImaging, 'rcb') && ~(opts.steeringUncertainty > 0 && opts.steeringUncertainty < 1)
        error('steeringUncertainty must be between 0 and 1.');
    end
end

function value = getField(structure, name, default)
    if isfield(structure, name) && ~isempty(structure.(name))
        value = structure.(name);
    else
        value = default;
    end
end

%% Propagation delay to every microphone for every direction [numMics x numDirections] (s)
function delays = steeringDelays(microphones, azimuthDeg, elevationDeg, opts)
    [ux, uy, uz] = sph2cart(deg2rad(azimuthDeg), deg2rad(elevationDeg), 1);
    directions = [ux; uy; uz];                                   % 3 x numDirections
    if isinf(opts.focusRange)
        delays = -(microphones * directions) / opts.speedOfSound;   % plane wave, relative to the origin
    else
        focusPoints = opts.focusRange * directions;
        distances = sqrt((microphones(:, 1) - focusPoints(1, :)).^2 + (microphones(:, 2) - focusPoints(2, :)).^2 + ...
                         (microphones(:, 3) - focusPoints(3, :)).^2);
        delays = (distances - opts.focusRange) / opts.speedOfSound;
    end
end

%% Cross-spectral matrices [numMics x numMics x numFrequencies], accumulated over snapshot batches
function R = crossSpectralMatrices(data, bins, hop, numSnapshots, opts)
    numMics = size(data, 2);
    L = opts.fftLength;
    window = cast(hann(L, 'periodic'), 'like', real(data));
    R = zeros(numMics, numMics, numel(bins), 'like', complex(data));
    batchSize = max(1, floor(2^24 / (L * numMics)));
    for first = 1:batchSize:numSnapshots
        snapshots = first:min(numSnapshots, first + batchSize - 1);
        sampleIndex = (1:L)' + (snapshots - 1) * hop;                          % L x numBatch
        frames = reshape(data(sampleIndex, :), L, numel(snapshots), numMics);  % L x numBatch x numMics
        spectra = fft(frames .* window, [], 1);
        X = permute(spectra(bins, :, :), [3 2 1]);                              % numMics x numBatch x numFrequencies
        R = R + pagemtimes(X, 'none', X, 'ctranspose');
    end
    R = R / numSnapshots;
end

%% Eigendecomposition of every cross-spectral matrix, for RCB
% (small numMics x numMics problems, solved on the CPU in double precision)
function [U, gamma] = eigenDecompositions(R)
    Rcpu = double(gather(R));
    [numMics, ~, numFrequencies] = size(Rcpu);
    U = zeros(numMics, numMics, numFrequencies, 'like', complex(Rcpu));
    gamma = zeros(numMics, 1, numFrequencies);
    for cntFrequency = 1:numFrequencies
        Rf = Rcpu(:, :, cntFrequency);
        [U(:, :, cntFrequency), D] = eig((Rf + Rf') / 2);
        gamma(:, 1, cntFrequency) = real(diag(D));
    end
    % Keep the eigenvalues positive so the loading equation always has a solution
    gamma = max(gamma, 1e-9 * max(gamma, [], 1));
end

%% Robust Capon beamformer power from the eigendecomposition [1 x numDirections x numFrequencies]
% The assumed steering vector a may be wrong by up to ||e||^2 <= epsilon. The worst-case
% steering vector is a - (I + lambda R)^-1 a, with lambda >= 0 solving
% ||(I + lambda R)^-1 a||^2 = epsilon, which is diagonal loading with lambda chosen per
% direction [Li, Stoica, Wang 2003]. With R = U diag(gamma) U' and z = U' a:
%   g(lambda) = sum |z|^2 / (1 + lambda gamma)^2 = epsilon
%   P = sum gamma^2 |z|^2 / (1 + lambda gamma)^2 / (M sum gamma |z|^2 / (1 + lambda gamma)^2)
% which is the Capon power of the corrected steering vector, scaled to norm^2 = M.
% lambda is found with Newton's method on 1/sqrt(g), which is nearly linear in lambda,
% starting from the lower bound of lambda given in the paper.
function power = robustCaponPower(U, gamma, A, opts)
    numMics = size(A, 1);
    epsilon = opts.steeringUncertainty * numMics;
    z2 = abs(pagemtimes(U, 'ctranspose', A, 'none')).^2;                        % numMics x numChunk x numFrequencies
    lambda = (sqrt(numMics) - sqrt(epsilon)) ./ (max(gamma, [], 1) * sqrt(epsilon));
    lambda = repmat(lambda, 1, size(A, 2), 1);
    for iteration = 1:30
        q = 1 + lambda .* gamma;
        g = sum(z2 ./ q.^2, 1);
        dg = -2 * sum(z2 .* gamma ./ q.^3, 1);
        % h = 1/sqrt(g) - 1/sqrt(epsilon), dh = -dg / (2 g^1.5)
        step = (1 ./ sqrt(g) - 1 / sqrt(epsilon)) .* (2 * g.^1.5) ./ dg;
        lambda = max(lambda + step, 0);
        if max(abs(step) ./ max(lambda, realmin('single')), [], 'all') < 1e-5
            break;
        end
    end
    q2 = (1 + lambda .* gamma).^2;
    power = sum(z2 .* gamma.^2 ./ q2, 1) ./ (numMics * sum(z2 .* gamma ./ q2, 1));
end

%% Batched GPU / CPU beamformer [numFrequencies x numDirections]
function power = vectorizedBeamformer(data, delays, frequencies, bins, hop, numSnapshots, opts)
    R = crossSpectralMatrices(data, bins, hop, numSnapshots, opts);
    numMics = size(R, 1);
    numFrequencies = numel(frequencies);
    numDirections = size(delays, 2);
    identity = eye(numMics, 'like', real(data));
    isMVDR = strcmpi(opts.methodImaging, 'mvdr');
    isRCB = strcmpi(opts.methodImaging, 'rcb');
    if isRCB
        [U, gamma] = eigenDecompositions(R);
        U = cast(U, 'like', complex(data));
        gamma = cast(gamma, 'like', real(data));
    end
    if isMVDR
        averagePower = real(sum(R .* identity, [1 2])) / numMics;             % 1 x 1 x numFrequencies
        R = R + opts.diagonalLoading * averagePower .* identity;
    elseif opts.removeDiagonal
        R = R .* (1 - identity);
    end
    normalization = numMics^2;
    if opts.removeDiagonal
        normalization = numMics^2 - numMics;
    end

    frequencyPages = reshape(frequencies, 1, 1, numFrequencies);
    power = zeros(numFrequencies, numDirections, 'like', real(data));
    chunk = max(1, floor(2^24 / (numMics * numFrequencies)));              % limit the steering vector memory
    for first = 1:chunk:numDirections
        index = first:min(numDirections, first + chunk - 1);
        A = exp(-1j * 2 * pi * delays(:, index) .* frequencyPages);          % numMics x numChunk x numFrequencies
        if isMVDR
            B = pagemldivide(R, A);                                          % R^-1 a without forming the inverse
            chunkPower = 1 ./ real(sum(conj(A) .* B, 1));
        elseif isRCB
            chunkPower = robustCaponPower(U, gamma, A, opts);
        else
            chunkPower = real(sum(conj(A) .* pagemtimes(R, A), 1)) / normalization;
        end
        power(:, index) = permute(chunkPower, [3 2 1]);
    end
end

%% Straightforward loop version [numFrequencies x numDirections]
function power = nativeBeamformer(data, delays, frequencies, bins, hop, numSnapshots, opts)
    numMics = size(data, 2);
    numFrequencies = numel(frequencies);
    numDirections = size(delays, 2);
    window = hann(opts.fftLength, 'periodic');
    isMVDR = strcmpi(opts.methodImaging, 'mvdr');

    % Cross-spectral matrix per frequency bin, averaged over the snapshots
    R = zeros(numMics, numMics, numFrequencies);
    for cntSnapshot = 1:numSnapshots
        samples = (cntSnapshot - 1) * hop + (1:opts.fftLength);
        spectra = fft(data(samples, :) .* window);
        for cntFrequency = 1:numFrequencies
            x = spectra(bins(cntFrequency), :).';
            R(:, :, cntFrequency) = R(:, :, cntFrequency) + x * x';
        end
    end
    R = R / numSnapshots;

    isRCB = strcmpi(opts.methodImaging, 'rcb');
    if isRCB
        [U, gamma] = eigenDecompositions(R);
    end
    power = zeros(numFrequencies, numDirections);
    for cntFrequency = 1:numFrequencies
        Rf = R(:, :, cntFrequency);
        if isMVDR
            Rf = Rf + opts.diagonalLoading * real(trace(Rf)) / numMics * eye(numMics);
        elseif opts.removeDiagonal
            Rf = Rf - diag(diag(Rf));
        end
        for cntDirection = 1:numDirections
            a = exp(-1j * 2 * pi * frequencies(cntFrequency) * delays(:, cntDirection));
            if isRCB
                power(cntFrequency, cntDirection) = robustCaponPower(U(:, :, cntFrequency), gamma(:, :, cntFrequency), a, opts);
            elseif isMVDR
                power(cntFrequency, cntDirection) = 1 / real(a' * (Rf \ a));
            elseif opts.removeDiagonal
                power(cntFrequency, cntDirection) = real(a' * Rf * a) / (numMics^2 - numMics);
            else
                power(cntFrequency, cntDirection) = real(a' * Rf * a) / numMics^2;
            end
        end
    end
end
