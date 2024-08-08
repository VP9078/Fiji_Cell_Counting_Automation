#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output

//Make separate image output folders for overlay and counts
	//Overlay
OverlayFolder = output + File.separator + "GFP_Overlay";
File.makeDirectory(OverlayFolder);
	//Counts
CountsFolder = output + File.separator + "GFP_Auto_Cell_Counts";
File.makeDirectory(CountsFolder);

//Turn on batch mode
setBatchMode(true);

processFolder(input);

// function to scan folder
function processFolder(input) {
	fileList = getFileList(input);
	fileList = Array.sort(fileList);
	for (i = 0; i < fileList.length; i++) {
		processFile(input, fileList[i], output);
	}
}

//Weka GFP Automated Positive Cell Detection
function processFile(input, filePath, output) {

	//File Selection
	filePath = input + File.separator + filePath;
	open(filePath);
	fileName = getInfo("image.filename");
	selectImage(fileName);

	//Make variable that is file name without .tif
	xtifFileName = fileName.substring(0,(indexOf(fileName,"tif")-1));

	//Get raw image
	getRawImage();

	//Select true raw image
	rawimg = "Raw_Image_"+i;
	selectImage(xtifFileName+"-0002");
	rename(rawimg); //rawimg is going to be overlayed upon, NOT doing cell classification

	//Crop Image (to remove scale bar)
	imgheight = getHeight();
	imgwidth = getWidth();
	crpdimgheight = imgheight*0.98;
	makeRectangle(0, 0, imgwidth, crpdimgheight);
	run("Crop");

	//Duplicate
	run("Duplicate...", " ");
	rawimgdup = rawimg+"-dup";
	rename(rawimgdup);
	selectImage(rawimgdup); //rawimgdup is doing the cell classification

	//Open Weka & Run Cell Classification
		//Get classifier path
	homeDir = call("java.lang.System.getProperty", "user.home");
	classifierPath = homeDir + "\\Box\\Helen Lai Lab\\Vihaan (HS Summer Intern)\\Cell Counting Automation\\Trainable Weka Segmentation\\GFP\\GFP_Classifier.model";
		//Run Weka
	setBatchMode("show");
	run("Trainable Weka Segmentation");
		// Extract the version number from the title
	wait(1000);
	wdttl = getInfo("window.title");
	version = wdttl.substring(indexOf(wdttl, "v"));
		// Print the version number to the Log window
	twsversion = "Trainable Weka Segmentation " + version;
	wait(3000);
		//Load Classifier
	selectWindow(twsversion);
	call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifierPath);
		//Get result
	call("trainableSegmentation.Weka_Segmentation.getResult");
	wait(10000);
	GFPfileName = "GFP_"+fileName;
	rename(GFPfileName);

	//Duplicate Image
	run("Duplicate...", " "); //Should be ClassifiedImage-1, ClassifiedImage should be the original
	overlaydup = "Overlay-Dup_"+i;
	rename(overlaydup);

	//Post classification image processing
	selectImage(GFPfileName);
	postProcess();

	//Get Count
	run("Analyze Particles...", "pixel show=[Overlay Masks] summarize");

	//Save Classified Image
	selectImage(GFPfileName);
	run("Grays");
	Autofilename = "GFP_Auto_Cell_Counts_" + fileName;
	saveAs("tiff", CountsFolder +File.separator+ Autofilename);

	//Make overlay image
	selectImage(rawimg);
	run("Green");
	run("Add Image...", "image="+overlaydup+" x=0 y=0 opacity=33");
	Overlayfilename = "GFP_Cell_Counts_Overlay_" + fileName;
	saveAs("tiff", OverlayFolder +File.separator+ Overlayfilename);

	//Close everything (other than Log and Summary)
	clseimg = newArray(Autofilename,overlaydup,Overlayfilename,twsversion,rawimgdup);
	for (i=0;i<clseimg.length;i++) {
		close(clseimg[i]);
	}

}



//Possibly varying functions (shouldn't edit anything else)
	//Split channels and acquire true raw image
function getRawImage() {
	//Split channels
	run("Split Channels");

	//Delete other stain channels
	close(fileName + " (blue)");
	close(fileName + " (red)");

	//Delete blank slices
	selectImage(fileName + " (green)");
	run("Stack to Images");
	close(xtifFileName+"-0004");
	close(xtifFileName+"-0003");
	close(xtifFileName+"-0001");
}

	//Image post-classification processing
function postProcess() {
	run("Invert");
	run("Auto Local Threshold", "method=Phansalkar radius=0.15 parameter_1=0 parameter_2=0 white");
	run("Median...", "radius=2");
	run("Remove Outliers...", "radius=6 threshold=50 which=Bright");
	run("Watershed");
}



//Put results in excel spreadsheet
getDateAndTime(year, month, week, day, hour, min, sec, msec);
month=month+1;
selectWindow("Summary");
saveAs("results", output + "//"+month+"."+day+"."+year+"_GFP_Cell_Count_Summary.xls");
