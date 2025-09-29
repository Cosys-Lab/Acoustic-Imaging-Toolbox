function success = compileCLAIT(enableCPU, enableGPU)
    %% CPU
    foundPath = findCLAITFolder();
    cd(char(foundPath.toAbsolutePath.toString));
    open("example.m")
end