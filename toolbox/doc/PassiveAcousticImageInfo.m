%[text] # Passive Acoustic Image Info
%[text] The function `calculatePassiveAcousticImage` makes acoustic images of sound sources that emit themselves, such as gas or air leaks, electrical discharges or machinery. Unlike `calculateAcousticImage` there is no emitted signal, so the image has no range: it estimates the power that arrives from every direction. Besides conventional delay-and-sum it offers the adaptive Capon (MVDR) beamformer and its robust version (RCB), which give a much higher resolution and a much lower background for these broadband, continuous signals.
%%
%[text] ## Theoretical Background
%[text] The function uses frequency-domain beamforming on the cross-spectral matrix of the microphone signals, as reviewed by Merino-Martínez et al. \[5\]:
%[text] 1. **Cross-spectral matrix.** The recording is split in overlapping Hann-windowed snapshots of `fftLength` samples that are Fourier transformed. For every frequency bin f in `frequencyRange` the cross-spectral (covariance) matrix R(f) is the average of the outer products of the snapshot spectra.
%[text] 2. **Steering vectors.** For every direction the steering vector a(f) holds the exact phase delays of a plane wave (or with `focusRange` a point source at that range) to every microphone.
%[text] 3. **Beamforming.** Per frequency the power arriving from a direction is
%[text]    - **DAS** (conventional, Bartlett): P = a' R a / M², with M the number of microphones.
%[text]    - **MVDR** (Capon \[1\]): P = 1 / (a' R⁻¹ a), the output power of the filter that passes the steered direction undistorted and suppresses all other directions as much as possible. R is diagonally loaded with `diagonalLoading` times the average microphone power to make it robust against estimation errors \[2, 3\].
%[text]    - **RCB** (robust Capon \[4\]): MVDR that allows the true steering vector to differ from the assumed one within a sphere of size `steeringUncertainty`·M. This works out to diagonal loading with the amount computed for every direction and frequency.
%[text] 4. **Broadband.** The narrowband maps are averaged over the frequency bins (incoherent averaging). \
%[text] For a single source all three methods give its power in its direction (plus the microphone noise power divided by M).
%[text] ### Which method to use
%[text:table]
%[text] | **Method** | **Resolution** | **Background** | **Source levels** | **Speed** |
%[text] | --- | --- | --- | --- | --- |
%[text] | `'DAS'` | Low (width of the array beam) | High sidelobes | Reliable | Fastest |
%[text] | `'MVDR'` | Highest | Low | Unreliable: a strong source is suppressed as soon as no image direction lies exactly on it | Fast |
%[text] | `'RCB'` | High | Lowest | Reliable | Slower, use the GPU |
%[text:table]
%[text] In a simulation with three sources and a 32 microphone array, imaged on a 1 degree direction grid, the strongest source came out 4.8 dB too low with MVDR, while RCB had no level error, a 40 dB lower median background than the peak (DAS: 13 dB), and still separated two sources 8 degrees apart with a 14 dB dip (DAS: 5 dB).
%[text] ### Practical notes
%[text] - **Snapshots.** MVDR and RCB need a well estimated R: at least as many snapshots as microphones, and about twice as many for less than 3 dB loss \[6\]. A warning is given otherwise. Record longer, use a shorter `fftLength`, or use more `fftOverlap`.
%[text] - **Uncorrelated sources.** The adaptive methods assume the sources are uncorrelated. Coherent sources, such as a source and its reflection, partially cancel.
%[text] - **Frequency band.** Choose `frequencyRange` where the sources are and the array has no grating lobes. The resolution improves with frequency.
%%
%[text] ## Namespace and Calling
%[text] The function is part of the CLAIT toolbox namespace and should be called using the full namespace qualifier:
[powerMap, powerPerFrequency, frequencies] = clait.calculatePassiveAcousticImage(dataMicrophones, structSensor, structImage)
%%
%[text] ## Input Arguments
%[text:table]
%[text] | **Argument** | **Type** | **Description** |
%[text] | --- | --- | --- |
%[text] | `dataMicrophones` | Matrix | Recorded microphone signals \[numSamples × numMics\] |
%[text] | `structSensor` | Struct | Sensor array configuration |
%[text] | `structImage` | Struct | Imaging and processing parameters, with defaults for the optional fields |
%[text:table]
%[text] #### 1. structSensor
%[text:table]
%[text] | **Field** | **Description** | **Dimensions/Units** |
%[text] | --- | --- | --- |
%[text] | `.coordinatesMicrophones` | Positions of the microphones | \[numMics × 3\] (m, right-handed system \[X Y Z\]) |
%[text] | `.sampleRate` | ADC sampling frequency | Hz |
%[text] | `.speedOfSound` | Speed of sound in the medium (default: 343) | m/s |
%[text:table]
%[text] #### 2. structImage
%[text:table]
%[text] | **Field** | **Description** | **Default** | **Options** |
%[text] | --- | --- | --- | --- |
%[text] | `.directionsAzimuth` | Azimuth angles to image, for example from `clait.generateDirections` | *(Mandatory)* | Degrees |
%[text] | `.directionsElevation` | Elevation angles to image | *(Mandatory)* | Degrees |
%[text] | `.methodImaging` | Beamforming method | `'MVDR'` | `'MVDR'`, `'RCB'`, `'DAS'` |
%[text] | `.methodProcessing` | Backend | `'mexcpu'` | `'mexcuda'` (NVIDIA GPU), `'mexcpu'` (CPU), `'native'` (loops). None needs a compiler |
%[text] | `.frequencyRange` | Frequency band to use | `[20e3 80e3]` | Hz |
%[text] | `.fftLength` | Snapshot length | `512` | Samples |
%[text] | `.fftOverlap` | Overlap of the snapshots | `0.5` | 0 to <1 |
%[text] | `.diagonalLoading` | MVDR loading relative to the average microphone power | `0.01` | ≥ 0 |
%[text] | `.steeringUncertainty` | RCB uncertainty sphere size relative to M. Larger is more robust, smaller gives more resolution | `0.05` | 0 to 1 |
%[text] | `.focusRange` | Range of the focus point, `Inf` = far field (plane waves) | `Inf` | m |
%[text] | `.removeDiagonal` | DAS only: remove the auto-spectra to suppress uncorrelated microphone noise | `false` | `true`, `false` |
%[text:table]
%%
%[text] ## Output
%[text:table]
%[text] | **Output** | **Description** | **Dimensions** |
%[text] | --- | --- | --- |
%[text] | `powerMap` | Broadband power per direction (mean over frequency) | \[1 × numDirections\] |
%[text] | `powerPerFrequency` | Power per frequency bin and direction | \[numFrequencies × numDirections\] |
%[text] | `frequencies` | Frequency of every bin | \[numFrequencies × 1\] (Hz) |
%[text:table]
%[text] The powers are relative (FFT units). Plot the power map with `clait.plotSphericalEnergyscape` using `options.valueType = 'power'` so the dB scale uses 10·log10.
%%
%[text] ## Simulating passive measurements
%[text] `clait.simulatePassiveMicrophoneData(structScene, structSensor)` simulates sources that emit independent band-limited noise, with exact fractional delays to every microphone. `structScene` holds `sourceAzimuth`, `sourceElevation`, optionally `sourceRange` (default `Inf`, far field), `sourceStrength` (RMS, default 1), `sourceBand` (default `[20e3 80e3]` Hz), `noiseLevel` (RMS microphone noise, default 0) and `speedOfSound`. Run `help clait.simulatePassiveMicrophoneData` for details.
%%
%[text] ## Examples
%[text] A full example comparing DAS, MVDR and RCB is available, to quickly open it after installing the toolbox, run the following command:
clait.openClaitPassiveAcousticImageExample
%%
%[text] ## References
%[text] \[1\] J. Capon, "High-resolution frequency-wavenumber spectrum analysis," *Proc. IEEE*, vol. 57, no. 8, pp. 1408–1418, 1969.
%[text] \[2\] B. D. Carlson, "Covariance matrix estimation errors and diagonal loading in adaptive arrays," *IEEE Trans. Aerosp. Electron. Syst.*, vol. 24, no. 4, pp. 397–401, 1988.
%[text] \[3\] H. Cox, R. M. Zeskind, M. M. Owen, "Robust adaptive beamforming," *IEEE Trans. Acoust., Speech, Signal Process.*, vol. 35, no. 10, pp. 1365–1376, 1987.
%[text] \[4\] J. Li, P. Stoica, Z. Wang, "On robust Capon beamforming and diagonal loading," *IEEE Trans. Signal Process.*, vol. 51, no. 7, pp. 1702–1715, 2003.
%[text] \[5\] R. Merino-Martínez et al., "A review of acoustic imaging methods using phased microphone arrays," *CEAS Aeronaut. J.*, vol. 10, no. 1, pp. 197–230, 2019.
%[text] \[6\] I. S. Reed, J. D. Mallett, L. E. Brennan, "Rapid convergence rate in adaptive arrays," *IEEE Trans. Aerosp. Electron. Syst.*, vol. AES-10, no. 6, pp. 853–863, 1974.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright","rightPanelPercent":13.2}
%---
