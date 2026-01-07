function sig=fm_sweep(f_start,f_end,fs,duration, amplitude, winprct)
%FM_SWEEP Generates a hyperbolic FM sweep signal with Hanning windowing.
%
%   sig = FM_SWEEP(f_start, f_end, fs, duration, amplitude, winprct) generates 
%   a frequency-modulated (FM) sweep signal, often used as a bat-like call. 
%   The frequency changes hyperbolically from a start frequency to an end 
%   frequency over a specified duration. The signal is then windowed with a 
%   Hanning window at its start and end to prevent spectral leakage.
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   f_start     : Start frequency of the sweep. [1 x 1] (Hz)
%
%   f_end       : End frequency of the sweep. [1 x 1] (Hz)
%
%   fs          : Sampling frequency. [1 x 1] (Hz)
%
%   duration    : Duration of the sweep. [1 x 1] (ms)
%
%   amplitude   : Amplitude of the generated signal. [1 x 1]
%
%   winprct     : Percentage of the signal duration to be covered by the 
%                 Hanning window at the start and end of the signal. [1 x 1] (%)
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   sig         : The generated FM sweep signal vector. [nSamples x 1]
%
%   NOTES:
%   - The frequency modulation is linear with respect to the period (1/f).
%   - The `duration` input is in milliseconds and is converted to seconds internally.
%   - The total length of the Hanning window is `2*winprct/100` of the signal length.

    % The time scale is in milliseconds, convert to seconds
    ms = 10^-3; 
    duration = duration * ms; 
    
    % Generate time vector
    t = 0:1/fs:duration; 
    
    % Generate the frequency modulation vector (linear with the period)
    ft = 1./(1/f_start + t * (1/f_end - 1/f_start) / duration); 
    
    % Generate the FM sweep signal
    sig = amplitude * (sin(2*pi*(duration/(1/f_end-1/f_start)) * (log(1/f_start+t*(1/f_end-1/f_start)/duration) - log(1/f_start))));
    
    % Apply Hanning window to the start and end of the signal
    length_win = round(length(sig)*2*winprct/100);
    window_short = hanning(length_win);
    window_on = window_short(1:ceil(length_win/2));
    window_off = window_short(ceil(length_win/2) + 1 : end);
    window = ones(1,length(sig));
    window(1:length(window_on)) = window_on;
    window(end-length(window_off) + 1 : end) = window_off;
    
    sig = sig .* window; 
end