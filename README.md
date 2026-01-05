
<a id="T_3400"></a>

# Cosys\-Lab Acoustic Imaging Toolbox

A MATLAB toolbox from Cosys\-Lab for high\-performance acoustic imaging, featuring GPU & MEX\-accelerated DMAS\-CF beamforming and signal processing.

<a id="H_4dd9"></a>

## Installation

Find the latest release [on Github](https://github.com/Cosys-Lab/Acoustic-Imaging-Toolbox/releases) or the MathWorks File Exchange for the toolbox. You can also clone or download this repository and use it from source.


Note that if you want to use any of the accelerated GPU and CPU\-based MEX implementations for beamforming you will first need to compile these MEX files. 


Once you have installed the toolbox you run the following command to automatically compile the source MEX files. Note that the GPU implementation requires an NVIDIA GPU!

```matlab
enableGPUCompile = true;
clait.compileClaitMexFunctions(enableGPUCompile)
```


<a id="TMP_77fd"></a>

## Dependencies

This toolbox requires the following other toolboxes installed as well:

-  Signal Processing Toolbox 
-  Image Processing Toolbox 
<a id="TMP_2c8c"></a>

## Examples

One example is available, to quickly open this file after installing the toolbox, run the following command or find it manually in the `examples` folder.

```matlab
clait.openClaitAcousticImageExample
```
<a id="H_33ac"></a>

## General Usage

The toolbox has 4 major functions: 1 main one and 3 helper ones. The following table lists all the available functions:

1.   `calculateAcousticImage:` Primary High\-Level Function. Executes the full imaging pipeline: Matched Filtering, Delay Calculation, Beamforming, and Post\-processing. mlx).
2. `calculateDMASCF:` Core beamforming function. Computes the image using D(M)AS(\-CF).
3. `calculateDelayMatrix:` Calculates the necessary sample delays array steering to specified directions.
4. `generalizedMatchedFilter:` Applies various matched filter and generalized correlation transforms (Normal, PHAT, ROTH, SCOT).
<a id="H_4320"></a>

All functions in this Toolbox exist within the `clait` namespace. For calling these functions you therefore have to add the namespace name to the beginning.


`output = clait.functionName(...)`

<a id="H_4b25"></a>

## Compiling MEX Files

You will have to compile the MEX files after installing the Toolbox or when using this repository from source. 

<a id="H_5795"></a>
##
## Dependencies
-  Parallel Computing Toolbox 
-  Compatible C MEX compiler 

For compatibility C MEX compiler dependent on your operating system, see this resource: [https://www.mathworks.com/support/requirements/supported\-compilers.html](https://www.mathworks.com/support/requirements/supported-compilers.html)


Make sure to correctly configure Matlab first for MEX compiling. Run the following command and make sure you either have the right compiler selected on Windows.

```matlab
mex -setup c++
```
<a id="H_464d"></a>

### Automatically Compiling MEX files when Toolbox is installed

Once you have installed the dependencies you can run the following command to automatically compile the source MEX files.

```matlab
enableGPUCompile = true;
clait.compileClaitMexFunctions(enableGPUCompile)
```
<a id="H_0889"></a>

### Manually Compiling MEX files

Go in your Matlab to the folder containing  `calculateDMASCFMex.cpp` (found in the toolbox\\+clait folder). 


Use the command below to compile the function:

```matlab
mex calculateDMASCFMexCPU.cpp
```

Go in your Matlab to the folder containing `calculateDMASCFGPU.cu` (found in the toolbox\\+clait folder). 


Use the command below to compile the function:

```matlab
mexcuda calculateDMASCFMexGPU.cu
```

You can use the `-v` argument to see the compilation process. If you run into compatibility errors you can also try the following command to get passed them.

```matlab
mexcuda NVCCFLAGS="--allow-unsupported-compiler" -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH -v calculateDMASCFGPU.cu
```
<a id="TMP_7eaa"></a>

## License

This project is released under the CC\-BY\-NC\-SA\-4.0 license.

