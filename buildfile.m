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
    
    % Make the "test" task the default task in the plan
    plan.DefaultTasks = ["mex" "generatedocs"];

    % Make the "release" task dependent on the "check" and "test" tasks
    plan("release").Dependencies = ["mex" "check"];
    plan("release").Outputs = "release\clait.mltbx";
end

function releaseTask(~)
    % Create an MLTBX package
    releaseFolderName = "release";
    % Create a release and put it in the release directory
    opts = matlab.addons.toolbox.ToolboxOptions("cosys-lab-acoustic-imaging-toolbox.prj");
    
    % By default, the packaging GUI restricts the name of the getting started guide, so we fix that here.
    opts.ToolboxGettingStartedGuide = fullfile("toolbox", "gettingStarted.mlx");
    
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
    
    mdfile = export("toolbox/GettingStarted.mlx","README.md", Format="markdown");
    % remove TOC and the links to the other mlx files from the readme!
    
    % Generate HTML pages
    htmldir = "toolbox\doc\html";
    if ~exist(htmldir, 'dir')
        mkdir(htmldir)
    end
    mdfile = export("toolbox/GettingStarted.mlx","toolbox/doc/html/GettingStarted.html", Format="html");
    mdfile = export("toolbox/doc/EnergyscapeInfo.mlx","toolbox/doc/html/EnergyscapeInfo.html", Format="html");
    mdfile = export("toolbox/doc/AcousticImageInfo.mlx","toolbox/doc/html/AcousticImageInfo.html", Format="html");
    mdfile = export("toolbox/examples/AcousticImageExample.mlx","toolbox/doc/html/AcousticImageExample.html", Format="html");
    mdfile = export("toolbox/examples/EnergyscapeExample.mlx","toolbox/doc/html/EnergyscapeExample.html", Format="html");
end

function gpuTask(~)
    try
        setenv("NVCC_APPEND_FLAGS", '-allow-unsupported-compiler')
        mexcuda -v toolbox\+clait\calculateDMASCFGPU.cu"    
    catch exception
        rethrow(exception)
    end

end