function varargout = plotPolarEnergyscape(varargin)
%PLOTPOLARENERGYSCAPE Create a polar acoustic image plot with intensity modulation.
%
%   [hPlot, hCbar] = PLOTPOLARENERGYSCAPE(imageData, structSensor, structImage, options)
%   creates a polar coordinate visualization of acoustic imaging data with advanced
%   visual enhancement options including intensity modulation, dynamic range control,
%   and customizable color mapping.
%
%   opts = PLOTPOLARENERGYSCAPE('options') returns a structure containing all
%   available plotting options with their default values.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Jan Steckel
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   imageData        : 2D acoustic image matrix from CLAIT beamforming.
%                      Dimensions: [numRangeBins x numAzimuthDirections]. (Mandatory for plotting)
%
%   structSensor     : Structure containing sensor array setup and signal characteristics. (Mandatory for plotting)
%       .sampleRate         : ADC sampling frequency. (Hz)
%       .numSamplesSensor   : Total number of samples in the acquisition.
%       .speedOfSound       : Speed of sound in the medium. Default: 343 (m/s, for air).
%
%   structImage      : Structure containing image formation parameters. (Mandatory for plotting)
%       .directionsAzimuth  : Vector of azimuth angles for the image. [numDirections x 1] (deg)
%       .decimationFactor   : Decimation factor applied to the acoustic image. Default: 1 (no decimation).
%
%   options          : Structure containing visualization parameters. (Optional - Defaulted if empty)
%                      Use plotPolarEnergyscape('options') to retrieve all available options.
%       .useSimplePlot      : Flag (true/false) for simple vs. advanced plotting. Default: false.
%                             true = basic pcolor plot, false = intensity-modulated visualization.
%       .useDbScale         : Flag (true/false) for dB vs. linear scale. Default: true.
%       .dbCut              : Lower dB limit relative to peak. Default: -60 (dB).
%       .dbMax              : Upper dB limit relative to peak. Default: 0 (dB).
%       .linearMin          : Minimum value for linear scale normalization. Default: 0.
%       .linearMax          : Maximum value for linear scale normalization. Default: 1.
%       .colormap           : Colormap matrix [N x 3]. Default: jet(1024).
%       .backgroundColor    : Background color specification. Default: 'w'.
%       .gridColor          : Grid line color [R G B] or string. Default: [0.7 0.7 0.7].
%       .rangeCompensation  : Range compensation exponent (R^n). Default: 2.
%       .angleCompStrength  : Angle compensation strength factor. Default: 3.
%       .tanhScale          : Tanh scaling factor for intensity. Default: 0.1.
%       .tanhOffset         : Tanh offset for intensity. Default: 0.5.
%       .intensityPower     : Power transform for contrast control. Default: 0.15.
%       .showGrid           : Flag (true/false) to display polar grid overlay. Default: true.
%       .gridRangeSpacing   : Spacing between range circles. Default: 0.5 (m).
%       .gridAzimuthSpacing : Spacing between azimuth lines. Default: 15 (deg).
%       .showColorbar       : Flag (true/false) to display colorbar. Default: true.
%       .xlabel             : X-axis label string. Default: 'Cross Range (m)'.
%       .ylabel             : Y-axis label string. Default: ''.
%       .title              : Plot title string. Default: ''.
%       .rangeSubsample     : Range subsampling factor for performance. Default: 1 (no subsample).
%       .normalizeToMax     : Flag (true/false) to normalize data to maximum. Default: true.
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   hPlot            : Handle to the pcolor plot object.
%   hCbar            : Handle to the colorbar object, or [] if colorbar is not shown.

    % Check if user is requesting options
    if nargin == 1 && ischar(varargin{1}) && strcmpi(varargin{1}, 'options')
        varargout{1} = getDefaultOptions();
        return;
    end
    
    % Normal plotting mode
    if nargin < 3
        error('plotPolarEnergyscape requires at least 3 inputs: imageData, structSensor, structImage');
    end
    
    imageData = varargin{1};
    structSensor = varargin{2};
    structImage = varargin{3};
    
    if nargin >= 4
        options = varargin{4};
    else
        options = struct();
    end
    
    % Get defaults and merge with user options
    defaults = getDefaultOptions();
    opts = mergeOptions(defaults, options);
    
    % Extract information from CLAIT structures
    azimuthVec = structImage.directionsAzimuth;
    
    % Calculate range vector
    if isfield(structSensor, 'speedOfSound')
        c = structSensor.speedOfSound;
    else
        c = 343;  % Default speed of sound in air
    end
    
    % Account for decimation if present
    decimationFactor = 1;
    if isfield(structImage, 'decimationFactor')
        decimationFactor = structImage.decimationFactor;
    end
    
    effectiveSampleRate = structSensor.sampleRate / decimationFactor;
    maxRange = structSensor.numSamplesSensor / structSensor.sampleRate * c / 2;
    numRangeBins = size(imageData, 1);
    rangeVec = linspace(0, maxRange, numRangeBins);
    
    % Apply range subsampling if requested (for performance)
    if opts.rangeSubsample > 1
        rangeIdx = 1:opts.rangeSubsample:length(rangeVec);
        rangeVec = rangeVec(rangeIdx);
        imageData = imageData(rangeIdx, :);
    end
    
    % Ensure colormap is correct size
    numColors = size(opts.colormap, 1);
    
    % Convert azimuth to radians
    azimuthRad = deg2rad(azimuthVec);
    
    %% Normalize data
    if opts.normalizeToMax
        imageDataNorm = imageData / max(imageData(:));
    else
        imageDataNorm = imageData;
    end
    
    %% Apply scale transformation (dB or linear)
    if opts.useDbScale
        % dB scale processing
        epsilon = 1e-10;
        imageDB = 20*log10(imageDataNorm + epsilon);
        
        % Apply dynamic range: clip to [peak + dbCut, peak + dbMax]
        peakDB = max(imageDB(:));
        imageDB = max(imageDB, peakDB + opts.dbCut);
        imageDB = min(imageDB, peakDB + opts.dbMax);
        
        % Normalize to [0, 1] for colormap
        dynamicRange = abs(opts.dbCut - opts.dbMax);
        imageScaled = (imageDB - (peakDB + opts.dbCut)) / dynamicRange;
        
        % Store for colorbar labels
        colorbarLabel = 'Relative Level (dB)';
        colorbarMin = opts.dbCut;
        colorbarMax = opts.dbMax;
    else
        % Linear scale processing
        % Apply min/max clipping
        imageLinear = imageDataNorm;
        imageLinear = max(imageLinear, opts.linearMin);
        imageLinear = min(imageLinear, opts.linearMax);
        
        % Normalize to [0, 1] for colormap
        imageScaled = (imageLinear - opts.linearMin) / (opts.linearMax - opts.linearMin);
        
        % Store for colorbar labels
        colorbarLabel = 'Normalized Amplitude';
        colorbarMin = opts.linearMin;
        colorbarMax = opts.linearMax;
    end
    
    %% Choose plotting method: Simple or Advanced
    if opts.useSimplePlot
        % Simple plot: just use the scaled data directly
        cdataFinal = imageScaled;
        
    else
        % Advanced plot: apply intensity modulation for visual enhancement
        imageIntensity = imageDataNorm;
        
        % Range compensation (R^2 to compensate for spherical spreading)
        if opts.rangeCompensation > 0
            imageIntensity = imageIntensity .* (rangeVec(:).^opts.rangeCompensation);
        end
        
        % Angle compensation (compensate for beam pattern)
        angleCompCurve = (1 + opts.angleCompStrength * sin(abs(azimuthRad))).^4;
        angleCompCurve = angleCompCurve / max(angleCompCurve);
        angleCompCurve = angleCompCurve + 1;
        imageIntensity = imageIntensity .* angleCompCurve;
        
        % Tanh transform for intensity (soft clipping)
        imageIntensity = tanh(opts.tanhScale * imageIntensity - opts.tanhOffset) + opts.tanhOffset;
        
        % Power transform for final intensity (contrast control)
        intensity = ((imageIntensity - min(imageIntensity(:))).^opts.intensityPower);
        
        % Color mapping
        % Map scaled values to colormap indices
        colorIndices = round(imageScaled * (numColors - 1)) + 1;
        colorIndices = max(1, min(numColors, colorIndices));  % Clamp to valid range
        
        % Get RGB colors
        cdataRGB = opts.colormap(colorIndices, :);
        
        % Apply intensity modulation
        cdataIntensified = cdataRGB .* repmat(intensity(:), 1, 3);
        
        % Reshape to image format
        cdataFinal = reshape(cdataIntensified, [size(imageScaled), 3]);
    end
    
    %% Convert to Cartesian coordinates
    [meshAz, meshRange] = meshgrid(azimuthRad, rangeVec);
    x = meshRange .* cos(meshAz);
    y = meshRange .* sin(meshAz);
    
    %% Create plot
    if opts.useSimplePlot
        % Simple pcolor with direct colormap
        hPlot = pcolor(-y, x, cdataFinal);
        set(hPlot, 'LineStyle', 'none');
    else
        % Advanced pcolor with RGB data
        hPlot = pcolor(-y, x, cdataFinal(:,:,1));
        hPlot.CData = cdataFinal;
        set(hPlot, 'LineStyle', 'none');
    end
    
    hold on;
    
    %% Add polar grid overlay
    if opts.showGrid
        addPolarGrid(azimuthRad, rangeVec, opts.gridRangeSpacing, ...
                     opts.gridAzimuthSpacing, opts.gridColor);
    end
    
    hold off;
    
    %% Formatting
    axis equal;
    axis tight;
    shading interp;
    
    curAx = gca();
    curAx.Color = opts.backgroundColor;
    curAx.XColor = 'k';
    curAx.YColor = 'w';
    yticks([]);
    box off;
    
    if ~isempty(opts.xlabel)
        xlabel(opts.xlabel);
    end
    if ~isempty(opts.ylabel)
        ylabel(opts.ylabel);
    end
    if ~isempty(opts.title)
        title(opts.title);
    end
    
    %% Colorbar
    if opts.showColorbar
        colormap(curAx, opts.colormap);
        clim([0 1]);
        
        hCbar = colorbar;
        
        % Create tick labels
        numTicks = 8;
        tickPositions = linspace(0, 1, numTicks);
        tickLabels = linspace(colorbarMin, colorbarMax, numTicks);
        
        set(hCbar, 'Ticks', tickPositions, 'TickLabels', tickLabels);
        hCbar.Label.String = colorbarLabel;
    else
        hCbar = [];
    end
    
    % Assign outputs
    if nargout >= 1
        varargout{1} = hPlot;
    end
    if nargout >= 2
        varargout{2} = hCbar;
    end
end

%% Get default options
function opts = getDefaultOptions()
% Returns a struct with all available options and their default values.

    opts = struct();
    
    % Plot style
    opts.useSimplePlot = false;    % true = simple pcolor, false = advanced with intensity modulation
    
    % Scale settings
    opts.useDbScale = true;        % true = dB scale, false = linear scale
    
    % dB scale settings (only used if useDbScale = true)
    opts.dbCut = -60;              % Lower dB limit relative to peak
    opts.dbMax = 0;                % Upper dB limit relative to peak
    
    % Linear scale settings (only used if useDbScale = false)
    opts.linearMin = 0;            % Minimum value for linear scale
    opts.linearMax = 1;            % Maximum value for linear scale
    
    % Visual appearance
    opts.colormap = jet(1024);     % Colormap to use
    opts.backgroundColor = 'w';    % Background color
    opts.gridColor = [0.7 0.7 0.7]; % Grid line color
    
    % Intensity modulation (only used if useSimplePlot = false)
    opts.rangeCompensation = 2;    % Range compensation exponent (R^n)
    opts.angleCompStrength = 3;    % Angle compensation strength
    opts.tanhScale = 0.1;          % Tanh scaling factor
    opts.tanhOffset = 0.5;         % Tanh offset
    opts.intensityPower = 0.15;    % Intensity power for contrast
    
    % Grid settings
    opts.showGrid = true;          % Show polar grid overlay
    opts.gridRangeSpacing = 0.5;   % Range grid spacing in meters
    opts.gridAzimuthSpacing = 15;  % Azimuth grid spacing in degrees
    
    % Display options
    opts.showColorbar = true;      % Show colorbar
    opts.xlabel = 'Cross Range (m)'; % X-axis label
    opts.ylabel = '';              % Y-axis label
    opts.title = '';               % Plot title
    
    % Performance
    opts.rangeSubsample = 1;       % Subsample range (1 = no subsample)
    
    % Normalization
    opts.normalizeToMax = true;    % Normalize data to its maximum
end

%% Helper function: Merge options
function merged = mergeOptions(defaults, userOptions)
    merged = defaults;
    if ~isempty(userOptions)
        fields = fieldnames(userOptions);
        for i = 1:length(fields)
            merged.(fields{i}) = userOptions.(fields{i});
        end
    end
end

%% Helper function: Add polar grid
function addPolarGrid(azimuthRad, rangeVec, rangeSpacing, azimuthSpacing, gridColor)
    azimuthSpacingRad = deg2rad(azimuthSpacing);
    
    % Generate range circles
    rangeGrid = rangeVec(1):rangeSpacing:rangeVec(end);
    if rangeGrid(end) < rangeVec(end)
        rangeGrid = [rangeGrid, rangeVec(end)];
    end
    
    % Fine azimuth sampling for smooth circles
    azimuthFine = linspace(azimuthRad(1), azimuthRad(end), 200);
    
    % Plot range circles
    for r = rangeGrid
        xCircle = r * cos(azimuthFine);
        yCircle = r * sin(azimuthFine);
        plot(-yCircle, xCircle, 'LineWidth', 0.5, 'Color', gridColor);
    end
    
    % Generate azimuth lines
    azimuthGrid = azimuthRad(1):azimuthSpacingRad:azimuthRad(end);
    if abs(azimuthGrid(end) - azimuthRad(end)) > deg2rad(1)
        azimuthGrid = [azimuthGrid, azimuthRad(end)];
    end
    
    % Fine range sampling for smooth radial lines
    rangeFine = linspace(rangeVec(1), rangeVec(end), 100);
    
    % Plot azimuth lines
    for az = azimuthGrid
        xLine = rangeFine * cos(az);
        yLine = rangeFine * sin(az);
        plot(-yLine, xLine, 'LineWidth', 0.5, 'Color', gridColor);
    end
end