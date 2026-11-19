function varargout = plotSphericalEnergyscape(varargin)
%PLOTSPHERICALENERGYSCAPE Plot the directional energy of an acoustic image on a sphere projection.
%
%   [hPlot, hCbar] = PLOTSPHERICALENERGYSCAPE(imageData, structSensor, structImage, options)
%   collapses the range dimension of an acoustic image to one value per direction
%   and plots these values over azimuth and elevation, either on a Lambert
%   azimuthal equal-area projection (default) or on an equirectangular
%   azimuth/elevation map, with a graticule, labelled axes and a colorbar.
%
%   opts = PLOTSPHERICALENERGYSCAPE('options') returns a structure containing all
%   available plotting options with their default values.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Wouter Jansen
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   imageData        : 2D acoustic image matrix from CLAIT beamforming.
%                      Dimensions: [numRangeBins x numDirections]. (Mandatory for plotting)
%                      A vector with one value per direction is plotted as is.
%
%   structSensor     : Structure containing sensor array setup and signal characteristics. (Mandatory for plotting)
%       .sampleRate         : ADC sampling frequency. (Hz)
%       .numSamplesSensor   : Total number of samples in the acquisition.
%       .speedOfSound       : Speed of sound in the medium. Default: 343 (m/s, for air).
%
%   structImage      : Structure containing image formation parameters. (Mandatory for plotting)
%       .directionsAzimuth   : Azimuth angles of the image columns. [numDirections x 1] (deg)
%       .directionsElevation : Elevation angles of the image columns. [numDirections x 1] (deg)
%       .decimationFactor    : Decimation factor applied to the acoustic image, used for rangeWindow.
%                              Default: 10 (as calculateAcousticImage).
%
%   options          : Structure containing visualization parameters. (Optional - Defaulted if empty)
%                      Use plotSphericalEnergyscape('options') to retrieve all available options.
%       .projection          : 'lambert' (equal-area sphere view) or 'equirectangular'
%                              (azimuth/elevation map). Default: 'lambert'.
%       .azimuthPositiveLeft : Flag (true/false) to draw positive azimuth on the left, as seen
%                              from the sensor (same as plotPolarEnergyscape). Default: true.
%       .rangeReduction      : How the range bins of a direction become one value.
%                              'max' (peak amplitude) or 'energy' (sum of squares). Default: 'max'.
%       .rangeWindow         : [minRange maxRange] in m to only use part of the range. Default: [] (all).
%       .useDbScale          : Flag (true/false) for dB vs. linear scale. Default: true.
%       .dbCut               : Lower dB limit relative to peak. Default: -60 (dB).
%       .dbMax               : Upper dB limit relative to peak. Default: 0 (dB).
%       .linearMin           : Minimum value for linear scale normalization. Default: 0.
%       .linearMax           : Maximum value for linear scale normalization. Default: 1.
%       .normalizeToMax      : Flag (true/false) to normalize data to maximum. Default: true.
%       .colormap            : Colormap matrix [N x 3]. Default: parula(1024).
%       .backgroundColor     : Background color specification. Default: 'w'.
%       .showGrid            : Flag (true/false) to display the graticule. Default: true.
%       .gridAzimuthSpacing  : Spacing between meridians. Default: 30 (deg).
%       .gridElevationSpacing: Spacing between parallels. Default: 30 (deg).
%       .gridColor           : Grid line color [R G B] or string. Default: 'k'.
%       .gridLineWidth       : Grid line width. Default: 0.75.
%       .showLabels          : Flag (true/false) to show angle labels. Default: true.
%       .labelStyle          : 'axes' = angle ticks and axis labels on the axes, 'graticule' = angle
%                              labels on the map next to the grid lines, axes hidden. Default: 'axes'.
%       .labelFontSize       : Font size of the 'graticule' labels. Default: 9.
%       .labelColor          : Color of the 'graticule' labels. Default: 'k'.
%       .xlabel              : X-axis label string ('axes' style). Default: 'Azimuth (°)'.
%       .ylabel              : Y-axis label string ('axes' style). Default: 'Elevation (°)'.
%       .title               : Plot title string. Default: ''.
%       .showColorbar        : Flag (true/false) to display colorbar. Default: true.
%       .colorbarLabel       : Colorbar label. Default: '' (automatic from the scale).
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   hPlot            : Handle to the patch object of the image.
%   hCbar            : Handle to the colorbar object, or [] if colorbar is not shown.

    % Check if user is requesting options
    if nargin == 1 && (ischar(varargin{1}) || isstring(varargin{1})) && strcmpi(varargin{1}, 'options')
        varargout{1} = getDefaultOptions();
        return;
    end

    % Normal plotting mode
    if nargin < 3
        error('plotSphericalEnergyscape requires at least 3 inputs: imageData, structSensor, structImage');
    end

    imageData = varargin{1};
    structSensor = varargin{2};
    structImage = varargin{3};
    options = struct();
    if nargin >= 4 && ~isempty(varargin{4})
        options = varargin{4};
    end
    opts = mergeOptions(getDefaultOptions(), options);

    azimuthDeg = double(structImage.directionsAzimuth(:));
    elevationDeg = double(structImage.directionsElevation(:));
    numDirections = numel(azimuthDeg);
    if numel(elevationDeg) ~= numDirections
        error('directionsAzimuth and directionsElevation must have the same number of elements.');
    end

    %% Collapse the range dimension to one value per direction
    directionValues = reduceRange(double(gather(imageData)), numDirections, structSensor, structImage, opts);

    %% Normalize and scale (dB or linear) to [0, 1]
    if opts.normalizeToMax
        directionValues = directionValues / max(directionValues);
    end
    if opts.useDbScale
        if strcmpi(opts.rangeReduction, 'energy')
            valuesDB = 10*log10(directionValues + 1e-20);   % energy is a power quantity
        else
            valuesDB = 20*log10(directionValues + 1e-10);   % peak is an amplitude quantity
        end
        peakDB = max(valuesDB);
        valuesDB = min(max(valuesDB, peakDB + opts.dbCut), peakDB + opts.dbMax);
        valuesScaled = (valuesDB - (peakDB + opts.dbCut)) / abs(opts.dbMax - opts.dbCut);
        colorbarLabel = 'Relative Level (dB)';
        colorbarLimits = [opts.dbCut opts.dbMax];
    else
        valuesLinear = min(max(directionValues, opts.linearMin), opts.linearMax);
        valuesScaled = (valuesLinear - opts.linearMin) / (opts.linearMax - opts.linearMin);
        colorbarLabel = 'Normalized Amplitude';
        colorbarLimits = [opts.linearMin opts.linearMax];
    end
    if ~isempty(opts.colorbarLabel)
        colorbarLabel = opts.colorbarLabel;
    end

    %% Project the directions and triangulate them
    [px, py] = projectDirections(azimuthDeg, elevationDeg, opts);
    % Directions that project to the same point (e.g. all azimuths at the poles) become one vertex.
    [vertices, ~, vertexIndex] = uniquetol([px py], 1e-9, 'ByRows', true);
    vertexValues = accumarray(vertexIndex, valuesScaled(:), [], @mean);
    faces = triangulateDirections(vertices(:, 1), vertices(:, 2));

    %% Plot
    curAx = gca();
    hPlot = patch(curAx, 'Faces', faces, 'Vertices', vertices, ...
        'FaceVertexCData', vertexValues, 'FaceColor', 'interp', 'EdgeColor', 'none');
    holdState = ishold(curAx);
    hold(curAx, 'on');

    azimuthLimits = snapLimits([min(azimuthDeg) max(azimuthDeg)], opts.gridAzimuthSpacing);
    elevationLimits = snapLimits([min(elevationDeg) max(elevationDeg)], opts.gridElevationSpacing);
    meridians = gridLines(azimuthLimits, opts.gridAzimuthSpacing);
    parallels = gridLines(elevationLimits, opts.gridElevationSpacing);
    covered = makeCoverageTest(azimuthDeg, elevationDeg);
    if opts.showGrid
        addGraticule(curAx, meridians, parallels, azimuthLimits, elevationLimits, covered, opts);
    end
    if ~holdState
        hold(curAx, 'off');
    end

    %% Formatting
    axis(curAx, 'equal');
    axis(curAx, 'tight');
    curAx.Color = opts.backgroundColor;
    curAx.Box = 'off';
    curAx.TickDir = 'out';
    if opts.showLabels && strcmpi(opts.labelStyle, 'axes')
        addAngleTicks(curAx, meridians, parallels, opts);
        if ~isempty(opts.xlabel)
            xlabel(curAx, opts.xlabel);
        end
        if ~isempty(opts.ylabel)
            ylabel(curAx, opts.ylabel);
        end
    elseif opts.showLabels && strcmpi(opts.labelStyle, 'graticule')
        curAx.XAxis.Visible = 'off';
        curAx.YAxis.Visible = 'off';
        addGraticuleLabels(curAx, meridians, parallels, azimuthLimits, elevationLimits, covered, opts);
    elseif opts.showLabels
        error('Unknown labelStyle: %s', opts.labelStyle);
    else
        curAx.XAxis.Visible = 'off';
        curAx.YAxis.Visible = 'off';
    end
    if ~isempty(opts.title)
        title(curAx, opts.title);
    end

    %% Colorbar
    colormap(curAx, opts.colormap);
    clim(curAx, [0 1]);
    if opts.showColorbar
        hCbar = colorbar(curAx);
        tickValues = niceTicks(colorbarLimits);
        hCbar.Ticks = (tickValues - colorbarLimits(1)) / diff(colorbarLimits);
        hCbar.TickLabels = compose('%g', tickValues);
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

    % Projection
    opts.projection = 'lambert';       % 'lambert' or 'equirectangular'
    opts.azimuthPositiveLeft = true;   % Positive azimuth on the left, as seen from the sensor

    % Range collapse
    opts.rangeReduction = 'max';       % 'max' or 'energy'
    opts.rangeWindow = [];             % [minRange maxRange] in m, [] = all ranges

    % Scale settings
    opts.useDbScale = true;            % true = dB scale, false = linear scale
    opts.dbCut = -60;                  % Lower dB limit relative to peak
    opts.dbMax = 0;                    % Upper dB limit relative to peak
    opts.linearMin = 0;                % Minimum value for linear scale
    opts.linearMax = 1;                % Maximum value for linear scale
    opts.normalizeToMax = true;        % Normalize data to its maximum

    % Visual appearance
    opts.colormap = parula(1024);      % Colormap to use
    opts.backgroundColor = 'w';        % Background color

    % Grid settings
    opts.showGrid = true;              % Show graticule
    opts.gridAzimuthSpacing = 30;      % Meridian spacing in degrees
    opts.gridElevationSpacing = 30;    % Parallel spacing in degrees
    opts.gridColor = 'k';              % Grid line color
    opts.gridLineWidth = 0.75;         % Grid line width

    % Display options
    opts.showLabels = true;            % Show angle labels
    opts.labelStyle = 'axes';          % 'axes' = ticks and axis labels, 'graticule' = labels on the map
    opts.labelFontSize = 9;            % Font size of the graticule labels
    opts.labelColor = 'k';             % Color of the graticule labels
    opts.xlabel = 'Azimuth (°)';       % X-axis label
    opts.ylabel = 'Elevation (°)';     % Y-axis label
    opts.title = '';                   % Plot title
    opts.showColorbar = true;          % Show colorbar
    opts.colorbarLabel = '';           % '' = automatic from the scale
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

%% Helper function: Collapse the range bins of every direction to one value
function directionValues = reduceRange(imageData, numDirections, structSensor, structImage, opts)
    if isvector(imageData) && numel(imageData) == numDirections
        directionValues = abs(imageData(:));
        return;
    end
    if size(imageData, 2) ~= numDirections
        error('imageData must have one column per direction (%d), it has %d.', numDirections, size(imageData, 2));
    end

    if ~isempty(opts.rangeWindow)
        if isfield(structSensor, 'speedOfSound')
            c = structSensor.speedOfSound;
        else
            c = 343;  % Default speed of sound in air
        end
        decimationFactor = 10;  % calculateAcousticImage default
        if isfield(structImage, 'decimationFactor')
            decimationFactor = structImage.decimationFactor;
        end
        % Every image row is one (decimated) sample of the round-trip time
        rangeVec = (0:size(imageData, 1)-1) * decimationFactor / structSensor.sampleRate * c / 2;
        inWindow = rangeVec >= opts.rangeWindow(1) & rangeVec <= opts.rangeWindow(2);
        if ~any(inWindow)
            error('rangeWindow [%g %g] m contains no range bins (image covers 0 to %g m).', ...
                opts.rangeWindow(1), opts.rangeWindow(2), rangeVec(end));
        end
        imageData = imageData(inWindow, :);
    end

    switch lower(opts.rangeReduction)
        case 'max'
            directionValues = max(abs(imageData), [], 1)';
        case 'energy'
            directionValues = sum(imageData.^2, 1)';
        otherwise
            error('Unknown rangeReduction: %s', opts.rangeReduction);
    end
end

%% Helper function: Project azimuth/elevation (deg) to plot coordinates
function [px, py] = projectDirections(azimuthDeg, elevationDeg, opts)
    switch lower(opts.projection)
        case 'lambert'
            % Lambert azimuthal equal-area projection centred on the sensor axis
            % (azimuth 0, elevation 0). The front hemisphere maps to the unit disk.
            az = deg2rad(azimuthDeg);
            el = deg2rad(elevationDeg);
            k = sqrt(2 ./ max(1 + cos(el) .* cos(az), eps));
            px = k .* cos(el) .* sin(az) / sqrt(2);
            py = k .* sin(el) / sqrt(2);
        case 'equirectangular'
            px = azimuthDeg;
            py = elevationDeg;
        otherwise
            error('Unknown projection: %s', opts.projection);
    end
    if opts.azimuthPositiveLeft
        px = -px;
    end
end

%% Helper function: Triangulate the projected directions
function faces = triangulateDirections(px, py)
    faces = delaunay(px, py);
    % Remove long, thin triangles that bridge gaps or concave edges of the direction set.
    edgeLength = @(a, b) hypot(px(faces(:, a)) - px(faces(:, b)), py(faces(:, a)) - py(faces(:, b)));
    longestEdge = max([edgeLength(1, 2), edgeLength(2, 3), edgeLength(3, 1)], [], 2);
    faces = faces(longestEdge <= 4 * median(longestEdge), :);
end

%% Helper function: Snap data limits to a grid line when they are close to one
% (scattered direction patterns end just short of e.g. 90 degrees).
function limits = snapLimits(limits, spacing)
    nearest = round(limits / spacing) * spacing;
    close = abs(limits - nearest) < 0.1 * spacing;
    limits(close) = nearest(close);
end

%% Helper function: Grid line angles, the multiples of the spacing within the limits
function values = gridLines(limits, spacing)
    values = (ceil(limits(1) / spacing - 1e-9) * spacing) : spacing : (limits(2) + 1e-9);
end

%% Helper function: Test whether angles lie within the area covered by the directions
% (within 1.5 times the typical direction spacing of a direction), to clip the graticule.
function covered = makeCoverageTest(azimuthDeg, elevationDeg)
    [x, y, z] = sph2cart(deg2rad(azimuthDeg), deg2rad(elevationDeg), 1);
    vectors = uniquetol([x y z], 1e-9, 'ByRows', true);
    if size(vectors, 1) < 2
        covered = @(az, el) true(size(az));
        return;
    end
    sample = vectors(round(linspace(1, size(vectors, 1), min(300, size(vectors, 1)))), :);
    similarity = sort(sample * vectors', 2, 'descend');
    cosLimit = cos(1.5 * median(acos(min(1, similarity(:, 2)))));
    covered = @(az, el) coverageTest(az, el, vectors, cosLimit);
end

function inside = coverageTest(azimuthDeg, elevationDeg, vectors, cosLimit)
    [x, y, z] = sph2cart(deg2rad(azimuthDeg(:)), deg2rad(elevationDeg(:)), 1);
    inside = reshape(max([x y z] * vectors', [], 2) >= cosLimit, size(azimuthDeg));
end

%% Helper function: Meridian and parallel points, clipped to the covered area (NaN outside)
function [x, y] = graticuleLine(azimuthDeg, elevationDeg, covered, opts)
    [x, y] = projectDirections(azimuthDeg, elevationDeg, opts);
    outside = ~covered(azimuthDeg, elevationDeg);
    x(outside) = NaN;
    y(outside) = NaN;
end

%% Helper function: Draw meridians and parallels
function addGraticule(ax, meridians, parallels, azimuthLimits, elevationLimits, covered, opts)
    lineArgs = {'Color', opts.gridColor, 'LineWidth', opts.gridLineWidth, 'HandleVisibility', 'off'};
    elevationFine = linspace(elevationLimits(1), elevationLimits(2), 181)';
    for az = meridians
        [x, y] = graticuleLine(az * ones(size(elevationFine)), elevationFine, covered, opts);
        plot(ax, x, y, lineArgs{:});
    end
    azimuthFine = linspace(azimuthLimits(1), azimuthLimits(2), 181)';
    for el = parallels
        [x, y] = graticuleLine(azimuthFine, el * ones(size(azimuthFine)), covered, opts);
        plot(ax, x, y, lineArgs{:});
    end
end

%% Helper function: Angle ticks where the meridians cross the equator and the parallels the central meridian
function addAngleTicks(ax, meridians, parallels, opts)
    [xTicks, ~] = projectDirections(meridians(:), zeros(numel(meridians), 1), opts);
    [~, yTicks] = projectDirections(zeros(numel(parallels), 1), parallels(:), opts);
    [xTicks, order] = sort(xTicks);
    ax.XTick = xTicks;
    ax.XTickLabel = compose('%g', round(meridians(order), 1));
    [yTicks, order] = sort(yTicks);
    ax.YTick = yTicks;
    ax.YTickLabel = compose('%g', round(parallels(order), 1));
end

%% Helper function: Angle labels on the map itself, next to the graticule
function addGraticuleLabels(ax, meridians, parallels, azimuthLimits, elevationLimits, covered, opts)
    xLimits = xlim(ax);
    yLimits = ylim(ax);
    span = max(diff(xLimits), diff(yLimits));
    offset = 0.02 * span;
    textArgs = {'Color', opts.labelColor, 'FontSize', opts.labelFontSize, ...
                'Clipping', 'off', 'HandleVisibility', 'off'};
    degreeLabel = @(value) sprintf('%g°', round(value, 1));

    % Azimuth labels just above the equator (or the parallel closest to it), right of
    % each meridian. The rightmost one ends up just outside the right edge.
    labelElevation = min(max(0, elevationLimits(1)), elevationLimits(2));
    [mx, my] = graticuleLine(meridians(:), labelElevation * ones(numel(meridians), 1), covered, opts);
    for i = find(~isnan(mx'))
        text(ax, mx(i) + offset, my(i) + offset, degreeLabel(meridians(i)), textArgs{:}, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');
    end

    % Elevation labels outside the left edge where each parallel ends. In the Lambert
    % projection the ±90° parallels are single points, labelled above/below the pole.
    azimuthFine = linspace(azimuthLimits(1), azimuthLimits(2), 181)';
    for el = parallels
        if abs(el) >= 90 && strcmpi(opts.projection, 'lambert')
            if ~covered(0, el)
                continue;
            end
            [x, y] = projectDirections(0, el, opts);
            verticalAlignment = 'bottom';
            if el < 0
                verticalAlignment = 'top';
            end
            text(ax, x, y + sign(el) * offset, degreeLabel(el), textArgs{:}, ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', verticalAlignment);
        else
            [x, y] = graticuleLine(azimuthFine, el * ones(size(azimuthFine)), covered, opts);
            [xLeft, leftIndex] = min(x);   % min ignores NaN
            if isnan(xLeft)
                continue;
            end
            text(ax, xLeft - offset, y(leftIndex), degreeLabel(el), textArgs{:}, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
        end
    end

    % Make room for the labels outside the map, symmetric to keep the map centred.
    xlim(ax, xLimits + [-0.14 0.14] * span);
    ylim(ax, yLimits + [-0.07 0.07] * span);
end

%% Helper function: Round colorbar tick values
function ticks = niceTicks(limits)
    span = abs(diff(limits));
    steps = [0.1 0.2 0.25 0.5 1 2 5 10 20 25 50 100] * 10^floor(log10(span) - 1);
    step = steps(find(span ./ steps <= 8, 1));
    ticks = (ceil(limits(1) / step) * step) : step : limits(2);
end
