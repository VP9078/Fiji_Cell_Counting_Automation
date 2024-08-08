#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output

//Make separate image output folders for overlay and counts
	//Overlay
OverlayFolder = output + File.separator + "TrKC_Overlay";
File.makeDirectory(OverlayFolder);
	//Counts
CountsFolder = output + File.separator + "TrKC_Auto_Cell_Counts";
File.makeDirectory(CountsFolder);

processFolder(input);

// function to scan folder
function processFolder(input) {
	fileList = getFileList(input);
	fileList = Array.sort(fileList);
	for (i = 0; i < fileList.length; i++) {
		processFile(input, fileList[i], output);
	}
}

//Weka TrKC Automated Positive Cell Detection
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
	selectImage(xtifFileName+"-0003");
	rename(rawimg); //rawimg is going to be overlayed upon, NOT doing cell classification

	//Crop Image (to remove scale bar)
	imgheight = getHeight();
	imgwidth = getWidth();
	crpdimgheight = imgheight*0.98;
	makeRectangle(0, 0, imgwidth, crpdimgheight);
	run("Crop");


	//Open Labkit & Run Cell Classification
		//Get classifier path
	homeDir = call("java.lang.System.getProperty", "user.home");
	classifierPath = homeDir + "/Box/Helen Lai Lab/Vihaan (HS Summer Intern)/Cell Counting Automation/TrKC/TrKC_Classifier.classifier";
	
	//Run Labkit
    run("Segment Image With Labkit", "segmenter_file=["+ classifierPath + "] use_gpu=false");

	TrKCfileName = "TrKC_"+fileName;
	rename(TrKCfileName);

	//Post classification image processing
	selectImage(TrKCfileName);
	postProcess();
	
	//Duplicate Image
	run("Duplicate...", " ");
	overlaydup = "Overlay-Dup_"+i;
	rename(overlaydup);
	run("Auto Local Threshold", "method=Phansalkar radius=30 parameter_1=0 parameter_2=0 white");
	run("Magenta");

	//Get Count
	selectImage(TrKCfileName);
	run("Analyze Particles...", "size=16-Infinity pixel show=[Overlay Masks] summarize");

	//Save Classified Image
	selectImage(TrKCfileName);
	run("Grays");
	Autofilename = "TrKC_Auto_Cell_Counts_" + fileName;
	saveAs("tiff", CountsFolder +File.separator+ Autofilename);

	//Make overlay image
	selectImage(rawimg);
	run("Add Image...", "image="+overlaydup+" x=0 y=0 opacity=33");
	Overlayfilename = "TrKC_Cell_Counts_Overlay_" + fileName;
	saveAs("tiff", OverlayFolder +File.separator+ Overlayfilename);

	//Close everything (other than Log and Summary)
	clseimg = newArray(Autofilename,overlaydup,Overlayfilename);
	for (i=0;i<clseimg.length;i++) {
		close(clseimg[i]);
	}

}



//Possibly varying functions (shouldn't edit anything else)
	//Split channels and acquire true raw image
function getRawImage() {
	//Split channels
	run("Stack to Images");

	//Delete blank slices

	close(xtifFileName+"-0004");
	close(xtifFileName+"-0002");
	close(xtifFileName+"-0001");
}

	//Image post-classification processing
function postProcess() {
	run("Auto Local Threshold", "method=Phansalkar radius=30 parameter_1=0 parameter_2=0 white");
	run("Remove Outliers...", "radius=10 threshold=50 which=Bright");
}



//Put results in excel spreadsheet
getDateAndTime(year, month, week, day, hour, min, sec, msec);
month=month+1;
selectWindow("Summary");
saveAs("results", output + "//"+month+"."+day+"."+year+"_TrKC_Cell_Count_Summary.xls");
