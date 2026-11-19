function varargout = plot3DEnergyscape(varargin)
%PLOT3DENERGYSCAPE Plot an acoustic image as a 3D point cloud or as 3D isosurfaces.
%
%   [hPlot, hCbar] = PLOT3DENERGYSCAPE(imageData, structSensor, structImage, options)
%   places every range bin of every direction of an acoustic image at its 3D
%   position (X forward, Y left, Z up, sensor at the origin) and shows the part
%   that lies within a dB window below the peak, either as a point cloud in
%   which louder points are larger and more opaque, or as nested semi-transparent
%   isosurfaces at chosen dB levels.
%
%   opts = PLOT3DENERGYSCAPE('options') returns a structure containing all
%   available plotting options with their default values.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Wouter Jansen
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   imageData        : 2D acoustic image matrix from CLAIT beamforming.
%                      Dimensions: [numRangeBins x numDirections]. (Mandatory for plotting)
%
%   structSensor     : Structure containing sensor array setup and signal characteristics. (Mandatory for plotting)
%       .sampleRate         : ADC sampling frequency. (Hz)
%       .numSamplesSensor   : Total number of samples in the acquisition.
%       .speedOfSound       : Speed of sound in the medium. Default: 343 (m/s, for air).
%
%   structImage      : Structure containing image formation parameters. (Mandatory for plotting)
%       .directionsAzimuth   : Azimuth angles of the image columns. [numDirections x 1] (deg)
%       .directionsElevation : Elevation angles of the image columns. [numDirections x 1] (deg)
%       .decimationFactor    : Decimation factor applied to the acoustic image. Default: 10 (as calculateAcousticImage).
%
%   options          : Structure containing visualization parameters. (Optional - Defaulted if empty)
%                      Use plot3DEnergyscape('options') to retrieve all available options.
%       .renderMode     : 'points' (point cloud) or 'isosurface' (nested surfaces). Default: 'points'.
%       .dbCut          : Lower end of the dB window relative to the peak. Points below it are
%                         not shown, and it is the bottom of the colorbar. Default: -30 (dB).
%       .rangeLimits    : [minRange maxRange] in m to only show part of the range, for example
%                         to hide the direct path at short range. Default: [] (all).
%       .normalizeToMax : Flag (true/false) to make the dB values relative to the peak. Default: true.
%       .colormap       : Colormap matrix [N x 3]. Default: parula(1024).
%       .backgroundColor: Background color specification. Default: 'w'.
%     Point cloud ('points'):
%       .markerSize     : Marker size of the loudest points (points^2). Default: 20.
%       .alphaRange     : [min max] opacity, from the weakest to the loudest points. Default: [0.05 0.9].
%       .maxPoints      : Maximum number of points, the loudest are kept. Default: 200000.
%     Isosurfaces ('isosurface'):
%       .isoLevels      : dB levels of the surfaces, relative to the peak. Default: [-6 -12 -20].
%       .isoAlphaRange  : [min max] opacity, from the lowest to the highest level. Default: [0.2 0.9].
%       .voxelSize      : Edge of the voxels the image is resampled on (m). Each voxel takes the
%                         maximum over the range bins it covers. Default: [] (automatic, about
%                         150 voxels over the largest side of the shown volume).
%       .smoothing      : Box size of the 3D smoothing of the volume (odd, voxels), 0 = off. Default: 3.
%     Display:
%       .showSensor     : Flag (true/false) to mark the sensor at the origin. Default: true.
%       .showColorbar   : Flag (true/false) to display colorbar. Default: true.
%       .colorbarLabel  : Colorbar label. Default: 'Relative Level (dB)'.
%       .viewAngle      : [azimuth elevation] of the camera, see VIEW. Default: [-130 20].
%       .xlabel, .ylabel, .zlabel : Axis labels. Default: 'X (m)', 'Y (m)', 'Z (m)'.
%       .title          : Plot title string. Default: ''.
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   hPlot            : Handle to the scatter object ('points') or array of patch objects,
%                      one per level ('isosurface').
%   hCbar            : Handle to the colorbar object, or [] if colorbar is not shown.

    % Check if user is requesting options
    if nargin == 1 && (ischar(varargin{1}) || isstring(varargin{1})) && strcmpi(varargin{1}, 'options')
        varargout{1} = getDefaultOptions();
        return;
    end

    % Normal plotting mode
    if nargin < 3
        error('plot3DEnergyscape requires at least 3 inputs: imageData, structSensor, structImage');
    end
    imageData = abs(double(gather(varargin{1})));
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
    if size(imageData, 2) ~= numDirections
        error('imageData must have one column per direction (%d), it has %d.', numDirections, size(imageData, 2));
    end

    %% Range of every row and dB values relative to the peak
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
    rangeVec = (0:size(imageData, 1)-1)' * decimationFactor / structSensor.sampleRate * c / 2;
    if ~isempty(opts.rangeLimits)
        imageData(rangeVec < opts.rangeLimits(1) | rangeVec > opts.rangeLimits(2), :) = 0;
    end
    reference = 1;
    if opts.normalizeToMax
        reference = max(imageData(:));
    end
    imageDB = 20 * log10(imageData / reference + 1e-12);

    %% Plot
    curAx = gca();
    holdState = ishold(curAx);
    hold(curAx, 'on');
    switch lower(opts.renderMode)
        case 'points'
            hPlot = plotPoints(curAx, imageDB, rangeVec, azimuthDeg, elevationDeg, opts);
        case 'isosurface'
            hPlot = plotIsosurfaces(curAx, imageDB, rangeVec, azimuthDeg, elevationDeg, opts);
        otherwise
            error('Unknown renderMode: %s', opts.renderMode);
    end
    if opts.showSensor
        plot3(curAx, 0, 0, 0, 'k^', 'MarkerFaceColor', 'k', 'MarkerSize', 7, 'HandleVisibility', 'off');
    end
    if ~holdState
        hold(curAx, 'off');
    end

    %% Formatting
    axis(curAx, 'equal');
    grid(curAx, 'on');
    box(curAx, 'on');
    view(curAx, opts.viewAngle);
    if strcmpi(opts.renderMode, 'isosurface')
        lighting(curAx, 'gouraud');
        camlight(curAx, 'headlight');
    end
    curAx.Color = opts.backgroundColor;
    xlabel(curAx, opts.xlabel);
    ylabel(curAx, opts.ylabel);
    zlabel(curAx, opts.zlabel);
    if ~isempty(opts.title)
        title(curAx, opts.title);
    end

    %% Colorbar
    colormap(curAx, opts.colormap);
    clim(curAx, [0 1]);
    if opts.showColorbar
        hCbar = colorbar(curAx);
        tickValues = niceTicks([opts.dbCut 0]);
        hCbar.Ticks = (tickValues - opts.dbCut) / -opts.dbCut;
        hCbar.TickLabels = compose('%g', tickValues);
        hCbar.Label.String = opts.colorbarLabel;
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
    opts.renderMode = 'points';        % 'points' or 'isosurface'
    opts.dbCut = -30;                  % Lower end of the dB window relative to the peak
    opts.rangeLimits = [];             % [minRange maxRange] in m, [] = all
    opts.normalizeToMax = true;        % dB relative to the peak
    opts.colormap = parula(1024);      % Colormap to use
    opts.backgroundColor = 'w';        % Background color

    % Point cloud
    opts.markerSize = 20;              % Marker size of the loudest points
    opts.alphaRange = [0.05 0.9];      % Opacity from the weakest to the loudest points
    opts.maxPoints = 200000;           % Keep at most this many (loudest) points

    % Isosurfaces
    opts.isoLevels = [-6 -12 -20];     % Surface levels in dB relative to the peak
    opts.isoAlphaRange = [0.2 0.9];    % Opacity from the lowest to the highest level
    opts.voxelSize = [];               % Voxel edge (m), [] = automatic
    opts.smoothing = 3;                % 3D smoothing box size, 0 = off

    % Display
    opts.showSensor = true;            % Mark the sensor at the origin
    opts.showColorbar = true;          % Show colorbar
    opts.colorbarLabel = 'Relative Level (dB)';
    opts.viewAngle = [-130 20];        % Camera azimuth and elevation
    opts.xlabel = 'X (m)';
    opts.ylabel = 'Y (m)';
    opts.zlabel = 'Z (m)';
    opts.title = '';
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

%% Helper function: Map dB values to [0, 1] over the dB window
function scaled = scaleDB(valuesDB, opts)
    scaled = min(max((valuesDB - opts.dbCut) / -opts.dbCut, 0), 1);
end

%% Helper function: Point cloud of all samples within the dB window
function hPlot = plotPoints(ax, imageDB, rangeVec, azimuthDeg, elevationDeg, opts)
    index = find(imageDB >= opts.dbCut);
    if isempty(index)
        error('No part of the image lies within dbCut = %g dB of the peak.', opts.dbCut);
    end
    % Draw the weakest first so the loudest are on top, and keep only the loudest maxPoints.
    [valuesDB, order] = sort(imageDB(index), 'ascend');
    index = index(order);
    if numel(index) > opts.maxPoints
        index = index(end - opts.maxPoints + 1:end);
        valuesDB = valuesDB(end - opts.maxPoints + 1:end);
    end
    [rangeIndex, directionIndex] = ind2sub(size(imageDB), index);
    [x, y, z] = sph2cart(deg2rad(azimuthDeg(directionIndex)), deg2rad(elevationDeg(directionIndex)), rangeVec(rangeIndex));

    scaled = scaleDB(valuesDB, opts);
    sizes = opts.markerSize * (0.25 + 0.75 * scaled);
    alpha = opts.alphaRange(1) + diff(opts.alphaRange) * scaled;
    hPlot = scatter3(ax, x, y, z, sizes, scaled, 'filled', 'MarkerEdgeColor', 'none');
    hPlot.MarkerFaceAlpha = 'flat';
    hPlot.AlphaDataMapping = 'none';
    hPlot.AlphaData = alpha;
end

%% Helper function: Nested isosurfaces of the image resampled on a voxel grid
function hPlot = plotIsosurfaces(ax, imageDB, rangeVec, azimuthDeg, elevationDeg, opts)
    levels = sort(opts.isoLevels(:)', 'descend');
    lowestLevel = min(levels);

    % Directions as unit vectors, and their typical spacing to detect voxels outside the field of view.
    [dx, dy, dz] = sph2cart(deg2rad(azimuthDeg), deg2rad(elevationDeg), 1);
    directionVectors = [dx dy dz];
    if rank(directionVectors) < 3
        error('The isosurface mode needs directions that cover azimuth and elevation, use renderMode ''points'' for 2D images.');
    end
    sample = directionVectors(round(linspace(1, size(directionVectors, 1), min(300, size(directionVectors, 1)))), :);
    similarity = sort(sample * directionVectors', 2, 'descend');
    directionSpacing = median(acos(min(1, similarity(:, 2))));
    % Repeated directions (e.g. all azimuths at a pole of a grid) are kept once.
    [uniqueVectors, firstOfUnique] = uniquetol(directionVectors, 1e-9, 'ByRows', true);
    nearestDirection = delaunayTriangulation(uniqueVectors);

    % Volume to resample: the bounding box of everything a few dB below the lowest level.
    [rangeIndex, directionIndex] = find(imageDB >= lowestLevel - 6);
    if isempty(rangeIndex)
        error('No part of the image reaches the isoLevels.');
    end
    points = rangeVec(rangeIndex) .* directionVectors(directionIndex, :);
    lower = min(points, [], 1);
    upper = max(points, [], 1);
    voxelSize = opts.voxelSize;
    if isempty(voxelSize)
        voxelSize = max(upper - lower) / 150;
    end
    voxelSize = max(voxelSize, (prod(upper - lower + 4 * voxelSize) / 8e6)^(1/3));  % At most ~8 million voxels
    lower = lower - 2 * voxelSize;
    upper = upper + 2 * voxelSize;
    [X, Y, Z] = meshgrid(lower(1):voxelSize:upper(1), lower(2):voxelSize:upper(2), lower(3):voxelSize:upper(3));

    % dB value of every voxel: nearest direction, and the maximum over the range bins
    % the voxel covers, so reflections thinner than a voxel keep their peak.
    rangeStep = rangeVec(2) - rangeVec(1);
    binsPerVoxel = max(1, round(voxelSize / rangeStep));
    if binsPerVoxel > 1
        imageDB = movmax(imageDB, binsPerVoxel, 1);
    end
    voxelRange = sqrt(X.^2 + Y.^2 + Z.^2);
    voxelDirection = [X(:) Y(:) Z(:)] ./ max(voxelRange(:), eps);
    [uniqueOfVoxel, distance] = nearestNeighbor(nearestDirection, voxelDirection);
    directionOfVoxel = firstOfUnique(uniqueOfVoxel);
    rangeOfVoxel = round(voxelRange(:) / rangeVec(end) * (numel(rangeVec) - 1)) + 1;
    valid = rangeOfVoxel <= numel(rangeVec) & 2 * asin(distance / 2) <= 2 * directionSpacing;
    volume = (lowestLevel - 40) * ones(size(X));
    volume(valid) = imageDB(sub2ind(size(imageDB), rangeOfVoxel(valid), directionOfVoxel(valid)));
    if opts.smoothing > 1
        volume = smooth3(volume, 'box', opts.smoothing);
    end

    % One surface per level, the highest (innermost) level the most opaque.
    numColors = size(opts.colormap, 1);
    alphas = linspace(opts.isoAlphaRange(2), opts.isoAlphaRange(1), numel(levels));
    hPlot = gobjects(1, numel(levels));
    for i = 1:numel(levels)
        surface = isosurface(X, Y, Z, volume, levels(i));
        color = opts.colormap(round(scaleDB(levels(i), opts) * (numColors - 1)) + 1, :);
        hPlot(i) = patch(ax, surface, 'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', alphas(i));
        isonormals(X, Y, Z, volume, hPlot(i));
    end
end

%% Helper function: Round colorbar tick values
function ticks = niceTicks(limits)
    span = abs(diff(limits));
    steps = [0.1 0.2 0.25 0.5 1 2 5 10 20 25 50 100] * 10^floor(log10(span) - 1);
    step = steps(find(span ./ steps <= 8, 1));
    ticks = (ceil(limits(1) / step) * step) : step : limits(2);
end
