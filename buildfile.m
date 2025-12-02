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

     % Compile Cpp source code within cpp/*Mex into MEX functions
    plan("mex") = MexTask.forEachFile(["toolbox\+clait\calculateDMASCFMex.cpp"], mexOutputFolder);
    plan("mex").Description = "Build MEX functions";
   
    % Define the "check" task
    sourceFolder = files(plan, "toolbox");
    plan("check") = matlab.buildtool.tasks.CodeIssuesTask(sourceFolder,...
        IncludeSubfolders = true);
    
    plan.DefaultTasks = ["clean" "check" "mex" "gpu" "generatedocs" "release"];

    % Make the "release" task dependent on the others
    plan("release").Dependencies = ["check" "generatedocs"];
    plan("release").Outputs = "release\clait.mltbx";
end

function releaseTask(~)
    % Create an MLTBX package
    releaseFolderName = "release";
    % Create a release and put it in the release directory
    opts = matlab.addons.toolbox.ToolboxOptions("cosys-lab-acoustic-imaging-toolbox.prj");
    
    % By default, the packaging GUI restricts the name of the getting started guide, so we fix that here.
    opts.ToolboxGettingStartedGuide = fullfile("toolbox", "doc", "gettingStarted.mlx");
    
    % GitHub releases don't allow spaces, so replace spaces with underscores
    opts.OutputFile = fullfile(releaseFolderName, "clait.mltbx");
    
    % Create the release directory, if needed
    if ~exist(releaseFolderName,"dir")
        mkdir(releaseFolderName)
    end
    matlab.addons.toolbox.packageToolbox(opts);
end

function generatedocsTask(~)
    % Generate markdown readme
    
    mdfile = export("toolbox/doc/GettingStarted.mlx", "README.md", Format="markdown");
    
    % Clean up the README.md file
    cleanupReadme("README.md");
    
    % Generate HTML pages
    htmldir = "toolbox\doc\html";
    if ~exist(htmldir, 'dir')
        mkdir(htmldir)
    end
    mdfile = export("toolbox/doc/GettingStarted.mlx", "toolbox/doc/html/GettingStarted.html", Format="html");
    mdfile = export("toolbox/doc/EnergyscapeInfo.mlx", "toolbox/doc/html/EnergyscapeInfo.html", Format="html");
    mdfile = export("toolbox/doc/AcousticImageInfo.mlx", "toolbox/doc/html/AcousticImageInfo.html", Format="html");
    mdfile = export("toolbox/examples/AcousticImageExample.mlx", "toolbox/doc/html/AcousticImageExample.html", Format="html");
    mdfile = export("toolbox/examples/EnergyscapeExample.mlx", "toolbox/doc/html/EnergyscapeExample.html", Format="html");
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
    % 2. Lines with links to .mlx files
    linesToKeep = true(size(lines));
    
    for i = 1:length(lines)
        line = lines{i};
        % Check for MATLAB anchor links pattern: [text](#H_xxxx) or [text](#TMP_xxxx)
        if ~isempty(regexp(line, '\[.*?\]\(#[HT]_[a-zA-Z0-9]+\)', 'once'))
            linesToKeep(i) = false;
        end
        % Check for links to .mlx files
        if contains(line, '.mlx)')
            linesToKeep(i) = false;
        end
    end
    
    lines = lines(linesToKeep);
    
    % Write the cleaned content back to file
    fileContent = strjoin(lines, newline);
    fid = fopen(filename, 'w', 'n', 'UTF-8');
    fwrite(fid, fileContent, 'char');
    fclose(fid);
end

function gpuTask(~)
    try
        if ismac
            mexcuda NVCCFLAGS="--allow-unsupported-compiler" -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH "toolbox\+clait\calculateDMASCFGPU.cu" -output "toolbox\+clait\calculateDMASCFGPU.mexmaci64" 
        elseif isunix
            mexcuda NVCCFLAGS="--allow-unsupported-compiler" -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH "toolbox\+clait\calculateDMASCFGPU.cu" -output "toolbox\+clait\calculateDMASCFGPU.mexa64" 
        elseif ispc
            mexcuda NVCCFLAGS="--allow-unsupported-compiler" -D_ALLOW_COMPILER_AND_STL_VERSION_MISMATCH "toolbox\+clait\calculateDMASCFGPU.cu" -output "toolbox\+clait\calculateDMASCFGPU.mexmw64" 
        else
            disp('Platform not supported')
        end        
    catch exception
        rethrow(exception)
    end

end