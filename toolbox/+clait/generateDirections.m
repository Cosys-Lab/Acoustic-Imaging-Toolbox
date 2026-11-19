function [azimuth, elevation] = generateDirections(method, options)
%GENERATEDIRECTIONS Generate azimuth and elevation directions for beamforming.
%
%   [azimuth, elevation] = GENERATEDIRECTIONS(method, options) returns a set of
%   directions within a field of view, ready to use as
%   structImage.directionsAzimuth and structImage.directionsElevation.
%
%   opts = GENERATEDIRECTIONS('options') returns a structure containing all
%   available options with their default values.
%
%   By Cosys-Lab, University of Antwerp
%   Contributors: Wouter Jansen
%
%   INPUTS:
%   -----------------------------------------------------------------------
%   method           : Direction pattern. (Mandatory)
%       '2d'         : Azimuth fan at one elevation (options.elevation2D), for 2D imaging.
%       'grid'       : Regular azimuth/elevation grid. Directions bunch up towards the poles.
%       'equalarea'  : Recursive zonal equal-area (EQ) sphere partitioning: the centres of
%                      regions of equal area and small diameter. Nearly uniform.
%                      (P. Leopardi, "A partition of the unit sphere into regions of equal
%                      area and small diameter", ETNA 25, 2006.)
%       'fibonacci'  : Fibonacci (golden spiral) sphere. Nearly uniform.
%       'hexagonal'  : Hexagonal lattice on the Lambert azimuthal equal-area plane centred
%                      on the sensor axis. Uniform density, one direction exactly on axis.
%
%   options          : Structure with the pattern parameters. (Optional - Defaulted if empty)
%                      Use generateDirections('options') to retrieve all available options.
%       .spacing          : Approximate angular distance between neighbouring directions (deg).
%                           For 'grid' a [azimuth elevation] pair is also allowed. Default: 3.
%       .numDirections    : Target number of directions within the field of view, used instead
%                           of spacing when not empty ('equalarea', 'fibonacci', 'hexagonal').
%                           The result is close to, not exactly, this number. Default: [].
%       .azimuthLimits    : [min max] azimuth of the field of view (deg). Default: [-90 90].
%       .elevationLimits  : [min max] elevation of the field of view (deg). Default: [-90 90].
%       .coneAngle        : Only keep directions within this angle of the sensor axis
%                           (azimuth 0, elevation 0) (deg). Default: [] (no cone).
%       .elevation2D      : Elevation of the '2d' fan (deg). Default: 0.
%
%   OUTPUTS:
%   -----------------------------------------------------------------------
%   azimuth          : Azimuth angles. [1 x numDirections] (right-handed coordinate system, deg)
%   elevation        : Elevation angles. [1 x numDirections] (right-handed coordinate system, deg)

    if nargin == 1 && (ischar(method) || isstring(method)) && strcmpi(method, 'options')
        azimuth = getDefaultOptions();
        return;
    end
    if nargin < 2 || isempty(options)
        options = struct();
    end
    opts = mergeOptions(getDefaultOptions(), options);

    switch lower(method)
        case '2d'
            azimuth = rangeWithSpacing(opts.azimuthLimits, opts.spacing(1));
            elevation = opts.elevation2D * ones(size(azimuth));
        case 'grid'
            spacing = opts.spacing([1 end]);
            [azimuth, elevation] = meshgrid(rangeWithSpacing(opts.azimuthLimits, spacing(1)), ...
                                            rangeWithSpacing(opts.elevationLimits, spacing(2)));
        case 'equalarea'
            [azimuth, elevation] = equalAreaPoints(numOnSphere(opts));
        case 'fibonacci'
            [azimuth, elevation] = fibonacciPoints(numOnSphere(opts));
        case 'hexagonal'
            [azimuth, elevation] = hexagonalPoints(opts);
        otherwise
            error('Unknown method: %s. Options: ''2d'', ''grid'', ''equalarea'', ''fibonacci'', ''hexagonal''.', method);
    end

    azimuth = azimuth(:)';
    elevation = elevation(:)';
    if ~strcmpi(method, '2d')
        keep = insideFieldOfView(azimuth, elevation, opts);
        azimuth = azimuth(keep);
        elevation = elevation(keep);
    end
end

%% Get default options
function opts = getDefaultOptions()
% Returns a struct with all available options and their default values.

    opts = struct();
    opts.spacing = 3;                  % Approximate angle between neighbouring directions (deg)
    opts.numDirections = [];           % Target number of directions, overrides spacing if set
    opts.azimuthLimits = [-90 90];     % Field of view azimuth (deg)
    opts.elevationLimits = [-90 90];   % Field of view elevation (deg)
    opts.coneAngle = [];               % Optional cone around the sensor axis (deg)
    opts.elevation2D = 0;              % Elevation of the '2d' fan (deg)
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

%% Helper function: Equally spaced values within the limits, centred between them
% (includes both limits when the spacing divides the span).
function values = rangeWithSpacing(limits, spacing)
    numSteps = floor((limits(2) - limits(1)) / spacing + 1e-9);
    first = (limits(1) + limits(2)) / 2 - numSteps * spacing / 2;
    values = first + (0:numSteps) * spacing;
end

%% Helper function: Field of view mask
function keep = insideFieldOfView(azimuth, elevation, opts)
    tolerance = 1e-9;
    keep = azimuth >= opts.azimuthLimits(1) - tolerance & azimuth <= opts.azimuthLimits(2) + tolerance & ...
           elevation >= opts.elevationLimits(1) - tolerance & elevation <= opts.elevationLimits(2) + tolerance;
    if ~isempty(opts.coneAngle)
        offAxis = acosd(min(1, cosd(elevation) .* cosd(azimuth)));
        keep = keep & offAxis <= opts.coneAngle + tolerance;
    end
end

%% Helper function: Solid angle of the field of view (sr)
function area = fieldOfViewArea(opts)
    area = deg2rad(diff(opts.azimuthLimits)) * (sind(opts.elevationLimits(2)) - sind(opts.elevationLimits(1)));
    if ~isempty(opts.coneAngle)
        area = min(area, 2 * pi * (1 - cosd(opts.coneAngle)));
    end
end

%% Helper function: Number of points on the whole sphere for the requested density
function numSphere = numOnSphere(opts)
    if ~isempty(opts.numDirections)
        numSphere = round(opts.numDirections * 4 * pi / fieldOfViewArea(opts));
    else
        numSphere = round(4 * pi / deg2rad(opts.spacing(1))^2);
    end
    numSphere = max(numSphere, 2);
end

%% Helper function: Convert colatitude/longitude (rad) to azimuth/elevation (deg)
function [azimuth, elevation] = polarToAzEl(colatitude, longitude)
    elevation = 90 - rad2deg(colatitude);
    azimuth = rad2deg(mod(longitude + pi, 2 * pi) - pi);
end

%% Helper function: Recursive zonal equal-area sphere partitioning (Leopardi), centre points on S^2
function [azimuth, elevation] = equalAreaPoints(numPoints)
    regionArea = 4 * pi / numPoints;
    capArea = @(colatitude) 4 * pi * sin(colatitude / 2).^2;
    capColatitude = @(area) 2 * asin(sqrt(area / pi) / 2);

    % Polar caps, each one region.
    polarColatitude = capColatitude(regionArea);
    % Number of collars between the caps, each about one ideal region high.
    idealCollarAngle = sqrt(regionArea);
    numCollars = 0;
    if numPoints > 2
        numCollars = max(1, round((pi - 2 * polarColatitude) / idealCollarAngle));
    end

    % Ideal (fractional) number of regions per zone, rounded so the total stays numPoints.
    idealRegions = ones(1, numCollars + 2);
    if numCollars > 0
        collarAngle = (pi - 2 * polarColatitude) / numCollars;
        for collar = 1:numCollars
            top = polarColatitude + (collar - 1) * collarAngle;
            bottom = polarColatitude + collar * collarAngle;
            idealRegions(1 + collar) = (capArea(bottom) - capArea(top)) / regionArea;
        end
    end
    numRegions = zeros(size(idealRegions));
    discrepancy = 0;
    for zone = 1:numel(idealRegions)
        numRegions(zone) = round(idealRegions(zone) + discrepancy);
        discrepancy = discrepancy + idealRegions(zone) - numRegions(zone);
    end

    % Colatitudes of the zone boundaries so every zone has exactly its regions' area.
    boundaries = zeros(1, numCollars + 2);
    boundaries(1) = polarColatitude;
    regionsAbove = 1;
    for collar = 1:numCollars
        regionsAbove = regionsAbove + numRegions(1 + collar);
        boundaries(1 + collar) = capColatitude(regionsAbove * regionArea);
    end
    boundaries(end) = pi;

    % Region centres: the poles, and in each collar equally spaced longitudes at the
    % middle colatitude, rotated relative to the collar above to avoid aligned points.
    colatitude = zeros(1, numPoints);
    longitude = zeros(1, numPoints);
    pointIndex = 2;
    offset = 0;
    for collar = 1:numCollars
        numInCollar = numRegions(1 + collar);
        numInNext = numRegions(2 + collar);
        indices = pointIndex : pointIndex + numInCollar - 1;
        longitude(indices) = mod(((1:numInCollar) - 0.5) * 2 * pi / numInCollar + 2 * pi * offset, 2 * pi);
        colatitude(indices) = (boundaries(collar) + boundaries(collar + 1)) / 2;
        offset = offset + (1 / numInNext - 1 / numInCollar) / 2 + gcd(numInCollar, numInNext) / (2 * numInCollar * numInNext);
        pointIndex = pointIndex + numInCollar;
    end
    colatitude(numPoints) = pi;
    [azimuth, elevation] = polarToAzEl(colatitude, longitude);
end

%% Helper function: Fibonacci (golden spiral) sphere
function [azimuth, elevation] = fibonacciPoints(numPoints)
    index = 0:numPoints - 1;
    z = 1 - (2 * index + 1) / numPoints;
    longitude = index * pi * (3 - sqrt(5));
    [azimuth, elevation] = polarToAzEl(acos(z), longitude);
end

%% Helper function: Hexagonal lattice on the Lambert azimuthal equal-area plane
function [azimuth, elevation] = hexagonalPoints(opts)
    % Lattice distance on the plane (unit sphere: equal to the angle near the axis).
    if ~isempty(opts.numDirections)
        % Each lattice point covers sqrt(3)/2 * d^2 of the (equal-area) plane.
        latticeDistance = sqrt(fieldOfViewArea(opts) / opts.numDirections / (sqrt(3) / 2));
    else
        latticeDistance = deg2rad(opts.spacing(1));
    end

    % Lattice rows cover the whole projected sphere (a disk of radius 2) with a point at the origin.
    rowDistance = latticeDistance * sqrt(3) / 2;
    numRows = ceil(2 / rowDistance);
    numColumns = ceil(2 / latticeDistance) + 1;
    [column, row] = meshgrid(-numColumns:numColumns, -numRows:numRows);
    x = latticeDistance * (column + 0.5 * mod(row, 2));
    y = rowDistance * row;
    rho = hypot(x, y);
    inside = rho < 2;
    x = x(inside);
    y = y(inside);
    rho = rho(inside);

    % Inverse Lambert azimuthal equal-area projection centred on azimuth 0, elevation 0,
    % with x pointing towards positive azimuth (+Y) and y towards positive elevation (+Z).
    c = 2 * asin(rho / 2);
    sinElevation = zeros(size(rho));
    nonZero = rho > 0;
    sinElevation(nonZero) = y(nonZero) .* sin(c(nonZero)) ./ rho(nonZero);
    elevation = asind(sinElevation);
    azimuth = atan2d(x .* sin(c), rho .* cos(c));
end
