%[text] %[text:anchor:T_3400] # Cosys-Lab Acoustic Imaging Toolbox
%[text] A MATLAB toolbox from Cosys-Lab for high-performance acoustic imaging, featuring GPU & MEX-accelerated DMAS-CF beamforming and signal processing.
%%
%[text:tableOfContents]{"heading":"**Table of Contents**"}
%%
%[text] %[text:anchor:H_4dd9] ## Installation
%[text] Find the latest release [on Github](https://github.com/Cosys-Lab/Acoustic-Imaging-Toolbox/releases) or [the MathWorks File Exchange](https://nl.mathworks.com/matlabcentral/fileexchange/182979-cosys-lab-acoustic-imaging-toolbox) for the toolbox. You can also clone or download this repository and use it from source.
%[text] The GPU-accelerated beamforming works without compiling anything. It uses a precompiled CUDA kernel and only needs an NVIDIA GPU with its driver and the Parallel Computing Toolbox. No CUDA toolkit or C++ compiler is required.
%[text] The CPU-accelerated MEX implementation has to be compiled once after installing the toolbox. Run the following command to do so:
clait.compileClaitMexFunctions()
%[text] See [this section](internal:H_4b25) for more detail.
%%
%[text] ## Dependencies
%[text] This toolbox requires the following other toolboxes installed as well:
%[text] - Signal Processing Toolbox
%[text] - Image Processing Toolbox
%[text] - Parallel Computing Toolbox \
%%
%[text] ## Publication
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
%[text] ## Examples
%[text] Two example are available, to quickly open these files after installing the toolbox, run the following commands or find them manually in the `examples` folder.
clait.openClaitAcousticImageExample
clait.openClaitPlottingPolarEnergyscapeExample
%%
%[text] %[text:anchor:H_33ac] ## General Usage
%[text] The toolbox has 8 functions: 2 main ones and 6 helper ones. The following lists all the available functions:
%[text] 1. `calculateAcousticImage:` Primary high-level function. Executes the full imaging pipeline: Matched Filtering, Delay Calculation, Beamforming, and Post-processing. A seperate full help page available [here](file:.\AcousticImageInfo.m).
%[text] 2. `plotPolarEnergyscape:`  Primary high-level function. It plots advanced 2D polar coordinate visualizations of acoustic imaging data from CLAIT acoustic image generation function algorithms. A seperate full help page available [here](file:.\PlottingPolarEnergyscapeInfo.m).
%[text] 3. `calculateDMASCF:` Core beamforming function. Computes the image using D(M)AS(-CF).
%[text] 4. `calculateDelayMatrix:` Calculates the necessary sample delays array steering to specified directions.
%[text] 5. `generalizedMatchedFilter:` Applies various matched filter and generalized correlation transforms (Normal, PHAT, ROTH, SCOT).
%[text] 6. `fm_sweep:` Helper function that enerates a hyperbolic FM sweep signal with Hanning windowing.
%[text] 7. `normLog:` Helper function that normalizes a matrix and converts it to a logarithmic (dB) scale.
%[text] 8. `simulateMicrophoneData:` Helper function that generates simulated microphone data from point targets in a scene. \
%[text] %[text:anchor:H_4320] All functions in this Toolbox exist within the `clait` namespace. For calling these functions you therefore have to add the namespace name to the beginning.
%[text] `output = clait.functionName(...)`
%%
%[text] %[text:anchor:H_4b25] ## Compiling MEX Files
%[text] You will have to compile the CPU MEX file after installing the Toolbox or when using this repository from source. The GPU acceleration does not need this, it uses a precompiled CUDA kernel.
%[text] Any C++ compiler supported by MATLAB works, for example the free MinGW-w64 add-on on Windows. For the supported compilers per operating system, see this resource: [https://www.mathworks.com/support/requirements/supported-compilers.html](https://www.mathworks.com/support/requirements/supported-compilers.html)
%[text] Make sure to correctly configure Matlab first for MEX compiling. Run the following command and select a compiler if asked.
mex -setup c++
%[text] %[text:anchor:H_464d] ### Automatically Compiling MEX files
%[text] Run the following command to compile the CPU MEX file.
clait.compileClaitMexFunctions()
%[text] %[text:anchor:H_0889] ### Manually Compiling MEX files
%[text] Go in your Matlab to the folder containing `calculateDMASCFMex.cpp` (found in the toolbox\\+clait folder).
%[text] Use the command below to compile the function:
mex calculateDMASCFMex.cpp
%%
%[text] ## License
%[text] This project is released under the CC-BY-NC-SA-4.0 license.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":40}
%---
