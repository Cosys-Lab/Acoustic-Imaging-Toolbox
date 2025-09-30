function foundPath = findClaitToolboxFolder()
    tbxlist = com.mathworks.addons_toolbox.ToolboxManagerForAddOns().getInstalled();
    idx = arrayfun(@(x)startsWith(x.getName(),'Cosys-Lab Acoustic Imaging Toolbox'),tbxlist);
    foundPath = tbxlist(idx).getInstalledFolder();
end