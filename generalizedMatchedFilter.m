function dataMatchedFiltered = generalizedMatchedFilter( sigIn, sigBase, Method, freqRange, sampleRate )
%GENERALIZEDMATCHEDFILTER Calculates the Generalized Matched Filter using Fourier Transforms.
%
%   dataMatchedFiltered = GENERALIZEDMATCHEDFILTER(sigIn, sigBase, Method, ...
%                                                  freqRange, sampleRate) 
%   computes the generalized matched filter/cross-correlation of an input signal 
%   with a base signal using various frequency-domain weighting methods (PHAT, 
%   ROTH, SCOT) and applies an optional frequency band-pass window.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   sigIn            : Input signal. 
%                      Dimensions: [nSamples x 1]. (Mandatory)
%
%   sigBase          : Base Signal for Matched Filtering. 
%                      Dimensions: [nSamplesBase x 1]. (Mandatory)
%
%   Method           : String specifying the generalized Matched Filtering 
%                      method (weighting function in the frequency domain).
%                      Options: 
%                      'Normal' : Plain matched filtering (cross-correlation). (Default)
%                      'PHAT'   : Phase Transform.
%                      'ROTH'   : Roth-based correlation transform.
%                      'SCOT'   : Smoothed Coherence factor transform.
%
%   freqRange        : Bandwidth [freqMin freqMax] (in Hz) for which the 
%                      correlation should be considered (band-pass window).
%                      Dimensions: [1 x 2]. (Mandatory)
%
%   sampleRate       : Sample rate in Hz. (Mandatory)
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   dataMatchedFiltered : The computed generalized matched filtered output (correlation 
%                         function). The length is truncated back to the 
%                         original input signal length (nSamples).
%                         Dimensions: [nSamples x 1].
%
%   NOTES:
%   - The function uses zero-padding to the next power of two for efficient FFT 
%     calculation before processing.
%   - The output is equivalent to the cross-correlation of the two signals 
%     filtered according to the selected 'Method' and constrained by 'freqRange'.

    % Calculate number of samples
    nSamplesIn = length( sigIn );
    nSamplesBase = length( sigBase );
    nextPowerOfTwo = 2^ceil( log2( size( sigIn, 1 ) ) );

    % Perform zero-padding
    dataFFT = fft( [ sigIn ; zeros( nextPowerOfTwo - nSamplesIn, 1 ) ] );
    baseFFT = fft( [ sigBase;  zeros( nextPowerOfTwo - nSamplesBase, 1 ) ] );
        
    % Detect the type of transform, and execute it
    switch(Method)
        case 'Normal'
            sigCorrFreqdom = dataFFT .* conj( baseFFT );

        case 'PHAT'
            sigCorrFreqdom = ( dataFFT .* conj( baseFFT ) ) ./ ( abs( dataFFT ) .* abs ( baseFFT ) );
            
        case 'ROTH'
            sigCorrFreqdom = ( dataFFT .* conj( baseFFT ) ) ./ ( dataFFT .* conj( dataFFT ) );
            
        case 'SCOT'
            sigCorrFreqdom = ( dataFFT .* conj( baseFFT ) ) ./ ( sqrt( dataFFT .* conj( dataFFT ) .* baseFFT .* conj( baseFFT ) ) );
        
        otherwise
            error( 'Method not known' )
    end
    
    % Do bandwidth Compensation:
    freqsFFT = 0:sampleRate/length(dataFFT):sampleRate/2;
    maskWindow = freqsFFT > freqRange(1) & freqsFFT < freqRange(2);   % Find frequencies of interest
    windowFunction = zeros( size( dataFFT ) );
    windowFunction( maskWindow ) = 1;
    
    % Perform the windowing
    sigCorrFreqdom = sigCorrFreqdom .* windowFunction;
    
    % Calculate inverse transform and remove zero-padding
    dataMatchedFiltered = ifft( sigCorrFreqdom, 'symmetric' );
    dataMatchedFiltered = dataMatchedFiltered( 1 : nSamplesIn ); 
end