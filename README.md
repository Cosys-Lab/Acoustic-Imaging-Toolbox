
# Cosys\-Lab Acoustic Imaging Toolbox

A MATLAB toolbox from Cosys\-Lab for high\-performance acoustic imaging, featuring GPU & MEX\-accelerated DMAS\-CF beamforming and signal processing.

<a name="beginToc"></a>

# Installation

Find the latest release [here](https://cosysgit.uantwerpen.be/wjansen/cosys-lab-acoustic-imaging-toolbox/-/releases) and use the download link for the toolbox. You can also clone or download this repository and use it from source.


Note that if you want to use any of the accelerated GPU and CPU\-based MEX implementations for beamforming you will first need to compile these MEX files. See the this section for how to do that!

# General Usage

The toolbox has 6 major functions: 2 main ones and 3 helper ones. The following table lists all the available functions:

1.   `calculateAcousticImage:` Primary High\-Level Function. Executes the full imaging pipeline: Matched Filtering, Delay Calculation, Beamforming, and Post\-processing. 
2. `calculateDMASCF:` Core beamforming function. Computes the image using D(M)AS(\-CF).
3. `calculateDelayMatrix:` Calculates the necessary sample delays array steering to specified directions.
4. `generalizedMatchedFilter:` Applies various matched filter and generalized correlation transforms (Normal, PHAT, ROTH, SCOT).
5. `generate2DEnergyscape:` Primary High\-Level Function. Generates a specific acoustic image called an Energyscape containing 2D azimuth/range/intensity data.
6. `plot2DEnergyscape:H`elper function to plot the generated Energyscape.


All functions in this Toolbox exist within the `clait` namespace. For calling these functions you therefore have to add the namespace name to the beginning.


`output = clait.functionName(...)`


# Examples

A few examples are available, to quickly open them after installing the toolbox, run the following commands or find them manually in the `examples` folder.

```matlab
clait.openClaitAcousticImageExample
clait.openClaitEnergyscapeExample
```

# Compiling MEX Files

You will have to compile the MEX files after installing the Toolbox or when using this repository from source. 


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
clait.compileClaitMexFunctions(enableCPUCompile, enableGPUCompile)
```


## Manually Compiling MEX files

Go in your Matlab to the folder containing `calculateDMASCFMexCPU.cpp (`found in the `+clait` folder`)`. 


Use the command below to compile the function:

```matlab
mex calculateDMASCFMexCPU.cpp
```

Go in your Matlab to the folder containing `calculateDMASCFMexGPU.cu (`found in the `+clait` folder`)`. 


Use the command below to compile the function:

```matlab
mexcuda -v calculateDMASCFMexGPU.cu
```

You can use the `-v` argument to see the compilation process.

