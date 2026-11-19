%[text] %[text:anchor:T_3400] # Acoustic Image Info
%[text] The primary function of the Acoustic Imaging Toolbox is `calculateAcousticImage`. It takes three inputs—raw data, sensor configuration, and imaging parameters—and outputs a complete, processed acoustic image.
%%
%[text] ## Theoretical Background
%[text] For more information on the implemented delay-multiply-and-sum (DMAS) beamforming technique, see our open-access publication [here](https://doi.org/10.1109/ACCESS.2026.3657901). 
%[text] If you do use this toolbox to generate acoustic images, please concider citing our work as:
%[text] ```
%[text] @ARTICLE{11363474,
%[text] author={Jansen, Wouter and Daems, Walter and Steckel, Jan},
%[text] journal={IEEE Access}, 
%[text] title={Delay-Multiply-And-Sum Beamforming for Real-Time In-Air Acoustic Imaging}, 
%[text]     year={2026},
%[text]     doi={10.1109/ACCESS.2026.3657901}}
%[text] ```
%%
%[text] %[text:anchor:H_61b0] ## **Namespace and calling functions**
%[text] %[text:anchor:H_4320] All functions in this Toolbox exist within the `clait` namespace. For calling these functions you therefore have to add the namespace name to the beginning.
%[text] `output = clait.calculateAcousticImage(...)`
%[text] %[text:anchor:H_8d31] ### **Function Signature**
%[text] `acousticImage = clait.calculateAcousticImage(dataMicrophones, structSensor, structImage)`
%%
%[text] %[text:anchor:H_3565] ## **Input Arguments**
%[text:table]{"ignoreHeader":true}
%[text] | **Argument** | **Type** | **Description** |
%[text] | --- | --- | --- |
%[text] | **`dataMicrophones`** | Matrix | **Received Signal Data.** This is the raw time-series data captured by the microphone array. |
%[text] |  |  | **Dimensions:** `[samples x channels]` (where `channels` is `numMics`). |
%[text] | **`structSensor`** | Struct | **Sensor Array & Signal Properties.** Defines the physical setup of the microphone array and the characteristics of the emitted signal. |
%[text] | **`structImage`** | Struct | **Imaging & Processing Parameters.** Controls the beamforming algorithm, acceleration method, and all post-processing steps. Contains extensive default values if fields are omitted. |
%[text:table]
%[text] 
%[text] %[text:anchor:H_102e] ### **Detailed Breakdown of Input Structures**
%[text] %[text:anchor:H_350e] #### **1. structSensor**
%[text] This structure provides the necessary physical and electrical context for the signal processing:
%[text:table]{"ignoreHeader":true}
%[text] | **Field** | **Description** | **Dimensions/Units** |
%[text] | --- | --- | --- |
%[text] | **`.coordinatesMicrophones`** | Positions of the array elements. | `[numMics x 3]` (m, right-handed system \[X Y Z\]) |
%[text] | **`.sampleRate`** | ADC sampling frequency. | (Hz) |
%[text] | **`.emissionSignal`** | The specific transmitted waveform used for matched filtering. | `[numSamplesBase x 1]` |
%[text] | **`.numSamplesSensor`** | Total number of samples in acquisition | samples |
%[text] | **.****`speedOfSound`** | Speed of sound in medium in m/s (default is 343) | m/s |
%[text:table]
%[text] 
%[text] %[text:anchor:H_9537] #### **2. structImage** 
%[text] This structure defines the entire acoustic imaging approach, from spatial sampling to output formatting. All optional fields will revert to a safe default if not provided.
%[text:table]{"ignoreHeader":true}
%[text] | **Field** | **Description** | **Default** | **Options** |
%[text] | --- | --- | --- | --- |
%[text] | **`.directionsAzimuth`** | Vector of azimuth angles of interest for beamforming. | *(None - Mandatory)* | Degrees (right-handed system) |
%[text] | **`.directionsElevation`** | Vector of elevation angles of interest for beamforming. | *(None - Mandatory)* | Degrees (right-handed system) |
%[text] | **`.methodImaging`** | Beamforming algorithm to use. | `'DAS'` | `'DAS'`, `'DMAS'`, `'DMAS3'`, `'DMAS4'`, `'DMAS5'` |
%[text] | **`.coherenceType`** | Coherence Factor applied to the beamformed output. | `'cf'` | `'none'`, `'cf'`, `'pcf'`, `'scf'` |
%[text] | **`.methodProcessing`** | Backend acceleration used for beamforming. | `'mexcpu'` | `'mexcuda'` (NVIDIA GPU, precompiled CUDA kernel, no compiling needed), `'mexcpu'` (CPU, compile once with `clait.compileClaitMexFunctions()`), `'native'` (MATLAB) |
%[text] | **`.doMatchedFilter`** | Flag to enable the matched filter preprocessing step (1=On, 0=Off). | `1` | `0`, `1` |
%[text] | **`.matchedFilterMethod`** | Generalized matched filter type. | `'Normal'` | `'Normal'`, `'PHAT'`, `'ROTH'`, `'SCOT'` |
%[text] | **`.matchedFilterFreq`** | The frequency band for the matched filter. | `[20e3 80e3]` | Vector in Hz |
%[text] | **`.doEnvelope`** | Flag to enable envelope detection (LPF of the absolute signal) (1=On, 0=Off). | `1` | `0`, `1` |
%[text] | **`.lowpassFreq`** | Cutoff frequency for the low-pass filter used in envelope detection. | `5e3` | Hz |
%[text] | **`.doThresholdAtZero`** | Flag to clip all negative image values to zero (1=On, 0=Off). | `1` | `0`, `1` |
%[text] | **`.decimationFactor`** | Factor N by which to downsample the final image in time/range. | `10` | Integer N≥1 |
%[text:table]
%%
%[text] %[text:anchor:H_2a43] ## **Output**
%[text:table]{"ignoreHeader":true}
%[text] | **Argument** | **Type** | **Description** |
%[text] | --- | --- | --- |
%[text] | **`acousticImage`** | Matrix | The final beamformed, processed image, ready for visualization. |
%[text] |  |  | **Dimensions:** `[(original samples / decimationFactor) x numDirections]` |
%[text:table]
%%
%[text] %[text:anchor:H_4b1e] ## Examples
%[text] A full example is available, to quickly open it after installing the toolbox, run the following command:
clait.openClaitAcousticImageExample
%%
%[text] %[text:anchor:H_00c8] ## Conversion from *Fast RTIS Processing in Matlab*
%[text] If you used the older toolbox, these are the basic steps to convert your code to use this newer, better toolbox. 
%[text] The new `clait.calculateAcousticImage` function simplifies the top-level call by organizing all configuration into two structures (`structSensor` and `structImage`), reducing the argument count from three to two primary structures plus the data.
%[text] The main changes required for conversion involve **data transposition** and **configuration restructuring**.
%[text] %[text:anchor:H_7386] ### Input Data Transposition
%[text] The most important change is the required orientation of the received data.
%[text:table]{"ignoreHeader":true}
%[text] | **Old Function (****`fastrtisprocessing`****)** | **New Function (****`calculateAcousticImage`****)** | **Action Needed** |
%[text] | --- | --- | --- |
%[text] | **`dataMatrix`** (`N x S`) | **`dataMicrophones`** (`S x C`) | **You MUST Transpose.** |
%[text] | Channels (`N`) are rows. | Samples (`S`) are rows. | `dataMicrophones = dataMatrix';` |
%[text] | Samples (`S`) are columns. | Channels (`C`) are columns. |  |
%[text:table]
%[text] %[text:anchor:H_98fb] ### 
%[text] %[text:anchor:H_41ef] ### Configuration Restructuring
%[text] Instead of using the flat `settingsStruct` and the separate `gpuToggle`, all settings are now organized into `structSensor` (hardware) and `structImage` (processing).
%[text] 
%[text] %[text:anchor:H_0e86] #### **Mapping Toggles and Processing Method**
%[text] The simple `0/1` toggles and the `gpuToggle` must be mapped to fields within `structImage`.
%[text:table]{"ignoreHeader":true}
%[text] | **Old Variable / Field** | **New Structure** | **New Field / Value** | **Description** |
%[text] | --- | --- | --- | --- |
%[text] | **`gpuToggle = 1`** | `structImage` | **`.methodProcessing = 'mexcuda'`** | Enables GPU acceleration. |
%[text] | **`gpuToggle = 0`** | `structImage` | **`.methodProcessing = 'mexcpu'`** | Uses the optimized CPU version. |
%[text] | **`settingsStruct.matchedFilterToggle`** | `structImage` | **`.doMatchedFilter`** | Direct 1:1 map (`1` or `0`). |
%[text] | **`settingsStruct.envelopeToggle`** | `structImage` | **`.doEnvelope`** | Direct 1:1 map (`1` or `0`). |
%[text] | **`settingsStruct.baseSignal`** | `structSensor` | **`.emissionSignal`** | Renamed for clarity. |
%[text:table]
%[text] %[text:anchor:H_7293] #### 
%[text] %[text:anchor:H_6013] #### **Removing Redundant Inputs**
%[text] The new function calculates filter coefficients and delays internally, simplifying setup:
%[text:table]{"ignoreHeader":true}
%[text] | **Old Field** | **New Approach** |
%[text] | --- | --- |
%[text] | **`settingsStruct.aLp`****,** **`settingsStruct.bLp`** | **REMOVE.** The new function calculates these based on `structImage.lowpassFreq` (default `5e3`) and `structSensor.sampleRate`. You only need to set the cutoff frequency in `structImage`. |
%[text] | **`settingsStruct.delayMatrix`** | **REMOVE.** The new function calculates this using a separate call to `calculateDelayMatrix` internally, using `structImage.directionsAzimuth`, `structImage.directionsElevation`, and `structSensor.coordinatesMicrophones`. |
%[text:table]
%[text] %[text:anchor:H_89d7] ### Required New Fields
%[text] You must define the following fields, which were previously implied or calculated separately:
%[text] - **`structSensor.coordinatesMicrophones`**: The coordinates used to calculate the delay matrix must now be passed via `structSensor`.
%[text] - **`structSensor.sampleRate`**: The sample rate is critical for internal calculations.
%[text] - **`structImage.directionsAzimuth`**: The full vector of directions must be included in `structImage`.
%[text] - **`structImage.directionsElevation`**: The elevation vector (even if all zeros).
%[text] - **`structImage.lowpassFreq`**: The desired low-pass filter cutoff frequency (e.g., `1000` Hz from the example). \

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright","rightPanelPercent":13.2}
%---
