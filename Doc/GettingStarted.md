
# Cosys\-Lab Acoustic Imaging Toolbox

A MATLAB toolbox from Cosys\-Lab for high\-performance acoustic imaging, featuring GPU & MEX\-accelerated DMAS\-CF beamforming and signal processing.

<a name="beginToc"></a>

## Table of Contents
&emsp;[Installation](#installation)
 
&emsp;[General Usage](#general-usage)
 
&emsp;&emsp;[**Function Signature**](#-textbf-function-signature-)
 
&emsp;&emsp;[**Input Arguments**](#-textbf-input-arguments-)
 
&emsp;&emsp;[**Detailed Breakdown of Input Structures**](#-textbf-detailed-breakdown-of-input-structures-)
 
&emsp;&emsp;&emsp;[**1. structSensor**](#-textbf-1-structsensor-)
 
&emsp;&emsp;&emsp;[**2. structImage**](#-textbf-2-structimage-)
 
&emsp;&emsp;[**Output**](#-textbf-output-)
 
&emsp;[Example](#example)
 
&emsp;[Compiling MEX Files](#compiling-mex-files)
 
&emsp;&emsp;[Dependencies](#dependencies)
 
&emsp;&emsp;[Automatically Compiling MEX files when Toolbox is installed](#automatically-compiling-mex-files-when-toolbox-is-installed)
 
&emsp;&emsp;[Manually Compiling MEX files](#manually-compiling-mex-files)
 
&emsp;[Conversion from *Fast RTIS Processing in Matlab*](#conversion-from-textit-fast-rtis-processing-in-matlab-)
 
&emsp;&emsp;[Input Data Transposition](#input-data-transposition)
 
&emsp;&emsp;[Configuration Restructuring](#configuration-restructuring)
 
&emsp;&emsp;&emsp;[**Mapping Toggles and Processing Method**](#-textbf-mapping-toggles-and-processing-method-)
 
&emsp;&emsp;&emsp;[**Removing Redundant Inputs**](#-textbf-removing-redundant-inputs-)
 
&emsp;&emsp;[Required New Fields](#required-new-fields)
 
<a name="endToc"></a>

# Installation

Find the latest release [here](https://cosysgit.uantwerpen.be/wjansen/cosys-lab-acoustic-imaging-toolbox/-/releases) and use the download link for the toolbox. You can also clone or download this repository and use it from source.s

# General Usage

 **Note that if you want to use any of the accelerated GPU and CPU\-based MEX implementations for beamforming you will first need to compile these MEX files. See the** **this section** **for how to do that!** 


The toolbox has four major functions: 1 main one and 3 helper ones. This readme will only dive deeper into the main one`.` The following table lists all the available functions:

|      |      |      |
| :-- | :-- | :-- |
| **Function Name** <br>  | **Description** <br>  | **Purpose** <br>   |
| `calculateAcousticImage` <br>  | Primary High\-Level Function. Executes the full imaging pipeline: Matched Filtering, Delay Calculation, Beamforming, and Post\-processing. <br>  | Image Generation <br>   |
| `calculateDMASCF` <br>  | Core beamforming function. Computes the image using D(M)AS(\-CF). <br>  | Beamforming <br>   |
| `calculateDelayMatrix` <br>  | Calculates the necessary sample delays array steering to specified directions. <br>  | Pre\-processing <br>   |
| `generalizedMatchedFilter` <br>  | Applies various matched filter and generalized correlation transforms (Normal, PHAT, ROTH, SCOT). <br>  | Signal Processing <br>   |
|      |      |       |


The primary function of the Acoustic Imaging Toolbox is `calculateAcousticImage`. It takes three inputs—raw data, sensor configuration, and imaging parameters—and outputs a complete, processed acoustic image.

## **Function Signature**

`acousticImage = calculateAcousticImage(dataMicrophones, structSensor, structImage)`

## **Input Arguments**
|      |      |      |
| :-- | :-- | :-- |
| **Argument** <br>  | **Type** <br>  | **Description** <br>   |
| **`dataMicrophones`** <br>  | Matrix <br>  | **Received Signal Data.** This is the raw time\-series data captured by the microphone array. <br>   |
|  |  | **Dimensions:** `[samples x channels]` (where `channels` is `numMics`). <br>   |
| **`structSensor`** <br>  | Struct <br>  | **Sensor Array | Signal Properties.** Defines the physical setup of the microphone array and the characteristics of the emitted signal. <br>   |
| **`structImage`** <br>  | Struct <br>  | **Imaging | Processing Parameters.** Controls the beamforming algorithm, acceleration method, and all post\-processing steps. Contains extensive default values if fields are omitted. <br>   |
|      |      |       |


## **Detailed Breakdown of Input Structures**
### **1. structSensor**

This structure provides the necessary physical and electrical context for the signal processing:

|      |      |      |
| :-- | :-- | :-- |
| **Field** <br>  | **Description** <br>  | **Dimensions/Units** <br>   |
| **`.coordinatesMicrophones`** <br>  | Positions of the array elements. <br>  | `[numMics x 3]` (m, right\-handed system \[X Y Z\]) <br>   |
| **`.sampleRate`** <br>  | ADC sampling frequency. <br>  | (Hz) <br>   |
| **`.emissionSignal`** <br>  | The specific transmitted waveform used for matched filtering. <br>  | `[numSamplesBase x 1]` <br>   |
|      |      |       |


###  **2. structImage** 

This structure defines the entire acoustic imaging approach, from spatial sampling to output formatting. All optional fields will revert to a safe default if not provided.

|      |      |      |      |
| :-- | :-- | :-- | :-- |
| **Field** <br>  | **Description** <br>  | **Default** <br>  | **Options** <br>   |
| **`.directionsAzimuth`** <br>  | Vector of azimuth angles of interest for beamforming. <br>  | *(None \- Mandatory)* <br>  | Degrees (right\-handed system) <br>   |
| **`.directionsElevation`** <br>  | Vector of elevation angles of interest for beamforming. <br>  | *(None \- Mandatory)* <br>  | Degrees (right\-handed system) <br>   |
| **`.methodImaging`** <br>  | Beamforming algorithm to use. <br>  | `'DAS'` <br>  | `'DAS'`, `'DMAS'`, `'DMAS3'`, `'DMAS4'`, `'DMAS5'` <br>   |
| **`.coherenceType`** <br>  | Coherence Factor applied to the beamformed output. <br>  | `'cf'` <br>  | `'none'`, `'cf'`, `'pcf'`, `'scf'` <br>   |
| **`.methodProcessing`** <br>  | Backend acceleration used for beamforming. <br>  | `'mexcpu'` <br>  | `'mexcuda'` (NVIDIA GPU), `'mexcpu'` (CPU), `'native'` (MATLAB) <br>   |
| **`.doMatchedFilter`** <br>  | Flag to enable the matched filter preprocessing step (1=On, 0=Off). <br>  | `1` <br>  | `0`, `1` <br>   |
| **`.matchedFilterMethod`** <br>  | Generalized matched filter type. <br>  | `'Normal'` <br>  | `'Normal'`, `'PHAT'`, `'ROTH'`, `'SCOT'` <br>   |
| **`.matchedFilterFreq`** <br>  | The frequency band for the matched filter. <br>  | `[20e3 80e3]` <br>  | Vector in Hz <br>   |
| **`.doEnvelope`** <br>  | Flag to enable envelope detection (LPF of the absolute signal) (1=On, 0=Off). <br>  | `1` <br>  | `0`, `1` <br>   |
| **`.lowpassFreq`** <br>  | Cutoff frequency for the low\-pass filter used in envelope detection. <br>  | `5e3` <br>  | Hz <br>   |
| **`.doThresholdAtZero`** <br>  | Flag to clip all negative image values to zero (1=On, 0=Off). <br>  | `1` <br>  | `0`, `1` <br>   |
| **`.decimationFactor`** <br>  | Factor N by which to downsample the final image in time/range. <br>  | `10` <br>  | Integer N≥1 <br>   |
|      |      |      |       |


## **Output**
|      |      |      |
| :-- | :-- | :-- |
| **Argument** <br>  | **Type** <br>  | **Description** <br>   |
| **`acousticImage`** <br>  | Matrix <br>  | The final beamformed, processed image, ready for visualization. <br>   |
|  |  | **Dimensions:** `[(original samples / decimationFactor) x numDirections]` <br>   |
|      |      |       |

# Example

A full example is available, to quickly open it after installing the toolbox, run the following command:

```matlab
openCLAITExample
```

# Compiling MEX Files

You will have to compile the 

## Dependencies
-  Parallel Computing Toolbox 
-  Compatible C MEX compiler. 

For compatibility C MEX compiler dependent on your operating system, see this resource: [https://www.mathworks.com/support/requirements/supported\-compilers.html](https://www.mathworks.com/support/requirements/supported-compilers.html)


Make sure to correctly configure Matlab first for MEX compiling. Run the following command and make sure you either have the right compiler selected on Windows.

```matlab
mex -setup c++
```

## Automatically Compiling MEX files when Toolbox is installed

Once you have installed the dependencies you can run the following command to automatically compile the source MEX files.

```matlab
enableCPUCompile = true;
enableGPUCompile = true;
compileCLAIT(enableCPUCompile, enableGPUCompile)
```

## Manually Compiling MEX files

Go in your Matlab to the folder containing `calculateDMASCFMexCPU.cpp`. Use the command below to compile the function:

```matlab
mex calculateDMASCFMexCPU.cpp
```

Go in your Matlab to the folder containing `calculateDMASCFMexGPU.cu`. Use the command below to compile the function:

```matlab
mexcuda -v calculateDMASCFMexGPU.cu
```

You can use the `-v` argument to see the compilation process.

# Conversion from *Fast RTIS Processing in Matlab*

If you used the older toolbox, these are the basic steps to convert your code to use this newer, better toolbox. 


The new `calculateAcousticImage` function simplifies the top\-level call by organizing all configuration into two structures (`structSensor` and `structImage`), reducing the argument count from three to two primary structures plus the data.


The main changes required for conversion involve **data transposition** and **configuration restructuring**.

## Input Data Transposition

The most important change is the required orientation of the received data.

|      |      |      |
| :-- | :-- | :-- |
| **Old Function (****`fastrtisprocessing`****)** <br>  | **New Function (****`calculateAcousticImage`****)** <br>  | **Action Needed** <br>   |
| **`dataMatrix`** (`N x S`) <br>  | **`dataMicrophones`** (`S x C`) <br>  | **You MUST Transpose.** <br>   |
| Channels (`N`) are rows. <br>  | Samples (`S`) are rows. <br>  | `dataMicrophones = dataMatrix';` <br>   |
| Samples (`S`) are columns. <br>  | Channels (`C`) are columns. <br>  |   |
|      |      |       |


## Configuration Restructuring

Instead of using the flat `settingsStruct` and the separate `gpuToggle`, all settings are now organized into `structSensor` (hardware) and `structImage` (processing).

### **Mapping Toggles and Processing Method**

The simple `0/1` toggles and the `gpuToggle` must be mapped to fields within `structImage`.

|      |      |      |      |
| :-- | :-- | :-- | :-- |
| **Old Variable / Field** <br>  | **New Structure** <br>  | **New Field / Value** <br>  | **Description** <br>   |
| **`gpuToggle = 1`** <br>  | `structImage` <br>  | **`.methodProcessing = 'mexcuda'`** <br>  | Enables GPU acceleration. <br>   |
| **`gpuToggle = 0`** <br>  | `structImage` <br>  | **`.methodProcessing = 'mexcpu'`** <br>  | Uses the optimized CPU version. <br>   |
| **`settingsStruct.matchedFilterToggle`** <br>  | `structImage` <br>  | **`.doMatchedFilter`** <br>  | Direct 1:1 map (`1` or `0`). <br>   |
| **`settingsStruct.envelopeToggle`** <br>  | `structImage` <br>  | **`.doEnvelope`** <br>  | Direct 1:1 map (`1` or `0`). <br>   |
| **`settingsStruct.baseSignal`** <br>  | `structSensor` <br>  | **`.emissionSignal`** <br>  | Renamed for clarity. <br>   |
|      |      |      |       |

### **Removing Redundant Inputs**

The new function calculates filter coefficients and delays internally, simplifying setup:

|      |      |
| :-- | :-- |
| **Old Field** <br>  | **New Approach** <br>   |
| **`settingsStruct.aLp`** **,** **`settingsStruct.bLp`** <br>  | **REMOVE.** The new function calculates these based on `structImage.lowpassFreq` (default `5e3`) and `structSensor.sampleRate`. You only need to set the cutoff frequency in `structImage`. <br>   |
| **`settingsStruct.delayMatrix`** <br>  | **REMOVE.** The new function calculates this using a separate call to `calculateDelayMatrix` internally, using `structImage.directionsAzimuth`, `structImage.directionsElevation`, and `structSensor.coordinatesMicrophones`. <br>   |
|      |       |


## Required New Fields

You must define the following fields, which were previously implied or calculated separately:

-  **`structSensor.coordinatesMicrophones`**: The coordinates used to calculate the delay matrix must now be passed via `structSensor`. 
-  **`structSensor.sampleRate`**: The sample rate is critical for internal calculations. 
-  **`structImage.directionsAzimuth`**: The full vector of directions must be included in `structImage`. 
-  **`structImage.directionsElevation`**: The elevation vector (even if all zeros). 
-  **`structImage.lowpassFreq`**: The desired low\-pass filter cutoff frequency (e.g., `1000` Hz from the example). 
