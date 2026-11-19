function plan = buildfile
    import matlab.buildtool.tasks.MexTask
    import matlab.buildtool.tasks.CleanTask
    import matlab.buildtool.tasks.CodeIssuesTask

    % Create a plan from the task functions
    plan = buildplan(localfunctions);
    
    % Define the "clean" Task
    plan("clean") = matlab.buildtool.tasks.CleanTask;
    
    % Output folder for MEX functions
    mexOutputFolder = fullfile("toolbox", "+clait");

    % Compile the CPU MEX function
    plan("mex") = MexTask.forEachFile(fullfile(mexOutputFolder, "calculateDMASCFMex.cpp"), mexOutputFolder);
    plan("mex").Description = "Build MEX functions";

    % Define the "check" task
    sourceFolder = files(plan, "toolbox");
    plan("check") = matlab.buildtool.tasks.CodeIssuesTask(sourceFolder,...
        IncludeSubfolders = true);

    plan.DefaultTasks = ["clean" "check" "mex" "ptx" "generatedocs" "release"];

    % Make the "release" task dependent on the others
    plan("release").Dependencies = ["check" "generatedocs"];
    plan("release").Outputs = fullfile("release", "clait.mltbx");
end

function releaseTask(~)
    % Create an MLTBX package
    releaseFolderName = "release";
    % Create a release and put it in the release directory
    opts = matlab.addons.toolbox.ToolboxOptions("cosys-lab-acoustic-imaging-toolbox.prj");
    
    % By default, the packaging GUI restricts the name of the getting started guide, so we fix that here.
    % Toolbox packaging needs an .mlx guide; generatedocs creates it from GettingStarted.m.
    opts.ToolboxGettingStartedGuide = fullfile("toolbox", "doc", "GettingStarted.mlx");
    
    % GitHub releases don't allow spaces, so replace spaces with underscores
    opts.OutputFile = fullfile(releaseFolderName, "clait.mltbx");
    
    % Create the release directory, if needed
    if ~exist(releaseFolderName,"dir")
        mkdir(releaseFolderName)
    end
    matlab.addons.toolbox.packageToolbox(opts);
end

function generatedocsTask(context)
    % Generate the .mlx getting started guide needed for toolbox packaging.
    % GettingStarted.m is the only file to edit, the .mlx is overwritten here.
    docFolder = fullfile(context.Plan.RootFolder, "toolbox", "doc");
    convertLiveScriptToMlx(fullfile(docFolder, "GettingStarted.m"), fullfile(docFolder, "GettingStarted.mlx"));

    % Generate markdown readme

    mdfile = export("toolbox/doc/GettingStarted.m", "README.md", Format="markdown");

    % Clean up the README.md file
    cleanupReadme("README.md");

    % Generate HTML pages
    htmldir = fullfile("toolbox", "doc", "html");
    if ~exist(htmldir, 'dir')
        mkdir(htmldir)
    end
    mdfile = export("toolbox/doc/GettingStarted.m", "toolbox/doc/html/GettingStarted.html", Format="html");
    mdfile = export("toolbox/doc/AcousticImageInfo.m", "toolbox/doc/html/AcousticImageInfo.html", Format="html");
    mdfile = export("toolbox/examples/AcousticImageExample.m", "toolbox/doc/html/AcousticImageExample.html", Format="html");
    mdfile = export("toolbox/doc/PlottingPolarEnergyscapeInfo.m", "toolbox/doc/html/PlottingPolarEnergyscapeInfo.html", Format="html");
    mdfile = export("toolbox/examples/PlottingPolarEnergyscapeExample.m", "toolbox/doc/html/PlottingPolarEnergyscapeExample.html", Format="html");
end

function cleanupReadme(filename)
    % Read the file
    fileContent = fileread(filename);
    lines = splitlines(fileContent);
    
    % Find and remove TOC section (between <!-- Begin Toc --> and <!-- End Toc -->)
    inToc = false;
    linesToKeep = true(size(lines));
    
    for i = 1:length(lines)
        if contains(lines{i}, '<!-- Begin Toc -->')
            inToc = true;
            linesToKeep(i) = false;
        elseif contains(lines{i}, '<!-- End Toc -->')
            inToc = false;
            linesToKeep(i) = false;
        elseif inToc
            linesToKeep(i) = false;
        end
    end
    
    lines = lines(linesToKeep);
    
    % Remove lines containing problematic links
    % 1. Lines with MATLAB-specific anchor links like [text](#H_xxxx)
    % 2. For lines with links to .mlx/.m files, remove only sentences with those links
    linesToKeep = true(size(lines));
    
    for i = 1:length(lines)
        line = lines{i};
        % Check for MATLAB anchor links pattern: [text](#H_xxxx) or [text](#TMP_xxxx)
        if ~isempty(regexp(line, '\[.*?\]\(#[HT]_[a-zA-Z0-9]+\)', 'once'))
            linesToKeep(i) = false;
            continue;
        end
        
        % Check for links to .mlx or .m files
        if contains(line, '.mlx)') || contains(line, '.m)')
            % Split line into sentences (split by period followed by space or end of string)
            sentences = regexp(line, '[^.]*\.(?:\s|$)', 'match');
            
            % If no sentences found (no periods), check the whole line
            if isempty(sentences)
                sentences = {line};
            end
            
            cleanSentences = {};
            for j = 1:length(sentences)
                sentence = sentences{j};
                % Keep sentence only if it doesn't contain .mlx or .m links
                if ~contains(sentence, '.mlx)') && ~contains(sentence, '.m)')
                    cleanSentences{end+1} = sentence;
                end
            end
            
            % Reconstruct the line if there are any clean sentences
            if ~isempty(cleanSentences)
                lines{i} = strjoin(cleanSentences, '');
                % Trim any extra whitespace
                lines{i} = strtrim(lines{i});
            else
                % If all sentences had problematic links, mark line for removal
                linesToKeep(i) = false;
            end
        end
    end
    
    lines = lines(linesToKeep);
    
    % Downgrade heading levels (except the first main title)
    % MATLAB exports title as #, but we want to keep first heading as # and downgrade all others
    firstHeadingFound = false;
    for i = 1:length(lines)
        line = lines{i};
        % Check if line is a markdown heading (starts with #)
        if ~isempty(line) && line(1) == '#'
            if ~firstHeadingFound
                % Keep the first heading as-is (the main title)
                firstHeadingFound = true;
            else
                % Downgrade all subsequent headings by one level (add one more #)
                lines{i} = ['#' line];
            end
        end
    end
    
    % Write the cleaned content back to file
    fileContent = strjoin(lines, newline);
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    fwrite(fid, fileContent, 'char');
    fclose(fid);
end

function convertLiveScriptToMlx(source, destination)
    % Save a plain-text live script (.m) as a binary live script (.mlx).
    % Work on a temporary copy so a copy of the source open in the Editor is never touched.
    tempFolder = tempname;
    mkdir(tempFolder);
    removeTemp = onCleanup(@() rmdir(tempFolder, "s"));
    [~, name, ext] = fileparts(source);
    tempSource = fullfile(tempFolder, name + ext);
    copyfile(source, tempSource);

    document = matlab.desktop.editor.openDocument(char(tempSource), "Visible", 0);
    closeDocument = onCleanup(@() document.closeNoPrompt);
    document.saveAs(char(destination));
end

function ptxTask(~)
    % Regenerate the precompiled CUDA kernel (PTX) that ships with the toolbox.
    % Only needed after changing calculateDMASCFKernel.cu. Needs the CUDA toolkit
    % (nvcc on the PATH or in MW_NVCC_PATH) and on Windows Visual Studio.
    % An older CUDA toolkit (e.g. 11.8) gives a PTX that also loads on older drivers.
    folder = fullfile("toolbox", "+clait");
    nvcc = "nvcc";
    if getenv("MW_NVCC_PATH") ~= ""
        nvcc = fullfile(getenv("MW_NVCC_PATH"), "nvcc");
    end

    % The host compiler only preprocesses here, so the version-mismatch workarounds are harmless.
    args = "-ptx -arch=compute_50 -allow-unsupported-compiler -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH";
    if ispc
        args = args + " -ccbin """ + findVisualStudioCompiler() + """";
    end

    command = sprintf('"%s" %s "%s" -o "%s"', nvcc, args, ...
        fullfile(folder, "calculateDMASCFKernel.cu"), fullfile(folder, "calculateDMASCFKernel.ptx"));
    [status, output] = system(command);
    assert(status == 0, "nvcc failed:\n%s", output);
end

function clFolder = findVisualStudioCompiler()
    % nvcc needs cl.exe, which is usually not on the PATH inside MATLAB.
    vsRoots = string.empty;
    compiler = mex.getCompilerConfigurations("C++", "Selected");
    if ~isempty(compiler) && contains(compiler.Name, "Visual")
        vsRoots = string(compiler.Location);
    end
    vswhere = fullfile(getenv("ProgramFiles(x86)"), "Microsoft Visual Studio", "Installer", "vswhere.exe");
    if isfile(vswhere)
        [~, found] = system(sprintf('"%s" -latest -products * -property installationPath', vswhere));
        vsRoots = [vsRoots, strtrim(string(splitlines(strtrim(found))))'];
    end
    for root = vsRoots
        cl = dir(fullfile(root, "VC", "Tools", "MSVC", "*", "bin", "Hostx64", "x64", "cl.exe"));
        if ~isempty(cl)
            clFolder = string(cl(end).folder);
            return
        end
    end
    error("Could not find Visual Studio (cl.exe), which nvcc needs on Windows.");
end