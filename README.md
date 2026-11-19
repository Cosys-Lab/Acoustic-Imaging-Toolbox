
<a id="T_3400"></a>

# Cosys\-Lab Acoustic Imaging Toolbox

A MATLAB toolbox from Cosys\-Lab for high\-performance acoustic imaging, featuring GPU & MEX\-accelerated DMAS\-CF beamforming and signal processing.

<a id="H_4dd9"></a>

## Installation

Find the latest release [on Github](https://github.com/Cosys-Lab/Acoustic-Imaging-Toolbox/releases) or [the MathWorks File Exchange](https://nl.mathworks.com/matlabcentral/fileexchange/182979-cosys-lab-acoustic-imaging-toolbox) for the toolbox. You can also clone or download this repository and use it from source.


The GPU\-accelerated beamforming works without compiling anything. It uses a precompiled CUDA kernel and only needs an NVIDIA GPU with its driver and the Parallel Computing Toolbox. No CUDA toolkit or C++ compiler is required.


The CPU\-accelerated MEX implementation has to be compiled once after installing the toolbox. Run the following command to do so:

```matlab
clait.compileClaitMexFunctions()
```


<a id="TMP_2238"></a>

## Dependencies

This toolbox requires the following other toolboxes installed as well:

-  Signal Processing Toolbox 
-  Image Processing Toolbox 
-  Parallel Computing Toolbox 
<a id="TMP_71b8"></a>

## Publication

For more information on the implemented delay\-multiply\-and\-sum (DMAS) beamforming technique, see our open\-access publication [here](https://doi.org/10.1109/ACCESS.2026.3657901). 


If you do use this toolbox to generate acoustic images, please concider citing our work as:

```
@ARTICLE{11363474,
author={Jansen, Wouter and Daems, Walter and Steckel, Jan},
journal={IEEE Access}, 
title={Delay-Multiply-And-Sum Beamforming for Real-Time In-Air Acoustic Imaging}, 
    year={2026},
    doi={10.1109/ACCESS.2026.3657901}}
```
<a id="TMP_0981"></a>

## Examples

Two example are available, to quickly open these files after installing the toolbox, run the following commands or find them manually in the `examples` folder.

```matlab
clait.openClaitAcousticImageExample
clait.openClaitPlottingPolarEnergyscapeExample
```
<a id="H_33ac"></a>

## General Usage

The toolbox has 8 functions: 2 main ones and 6 helper ones. The following lists all the available functions:

1.  `calculateAcousticImage:` Primary high\-level function. Executes the full imaging pipeline: Matched Filtering, Delay Calculation, Beamforming, and Post\-processing. m).
2. `plotPolarEnergyscape:`  Primary high\-level function. It plots advanced 2D polar coordinate visualizations of acoustic imaging data from CLAIT acoustic image generation function algorithms. m).
3. `calculateDMASCF:` Core beamforming function. Computes the image using D(M)AS(\-CF).
4. `calculateDelayMatrix:` Calculates the necessary sample delays array steering to specified directions.
5. `generalizedMatchedFilter:` Applies various matched filter and generalized correlation transforms (Normal, PHAT, ROTH, SCOT).
6. `fm_sweep:` Helper function that enerates a hyperbolic FM sweep signal with Hanning windowing.
7. `normLog:` Helper function that normalizes a matrix and converts it to a logarithmic (dB) scale.
8. `simulateMicrophoneData:` Helper function that generates simulated microphone data from point targets in a scene.
<a id="H_4320"></a>

All functions in this Toolbox exist within the `clait` namespace. For calling these functions you therefore have to add the namespace name to the beginning.


`output = clait.functionName(...)`

<a id="H_4b25"></a>

## Compiling MEX Files

You will have to compile the CPU MEX file after installing the Toolbox or when using this repository from source. The GPU acceleration does not need this, it uses a precompiled CUDA kernel.


Any C++ compiler supported by MATLAB works, for example the free MinGW\-w64 add\-on on Windows. For the supported compilers per operating system, see this resource: [https://www.mathworks.com/support/requirements/supported\-compilers.html](https://www.mathworks.com/support/requirements/supported-compilers.html)


Make sure to correctly configure Matlab first for MEX compiling. Run the following command and select a compiler if asked.

```matlab
mex -setup c++
```
<a id="H_464d"></a>

### Automatically Compiling MEX files

Run the following command to compile the CPU MEX file.

```matlab
clait.compileClaitMexFunctions()
```
<a id="H_0889"></a>

### Manually Compiling MEX files

Go in your Matlab to the folder containing `calculateDMASCFMex.cpp` (found in the toolbox\\+clait folder).


Use the command below to compile the function:

```matlab
mex calculateDMASCFMex.cpp
```
<a id="TMP_16f6"></a>

## License

This project is released under the CC\-BY\-NC\-SA\-4.0 license.

