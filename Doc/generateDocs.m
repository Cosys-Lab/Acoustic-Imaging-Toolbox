%% Generate markdown readme

mdfile = export("GettingStarted.mlx","../README.md", Format="markdown")
% remove TOC and the links tot he other mlx files from the readme!

%% Generate HTML pages
mdfile = export("GettingStarted.mlx","../help/help.html", Format="html")
mdfile = export("energyscapeInfo.mlx","../help/energyscapeInfo.html", Format="html")
mdfile = export("AcousticImageInfo.mlx","../help/AcousticImageInfo.html", Format="html")