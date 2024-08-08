#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output

// REQUIRES MorpholibJ; can install by doing the following:
// 1. Go to 'Help > Update ImageJ' or 'Help > Update Fiji'
// 2. Click on 'Manage Update Sites'
// 3. Enable the 'IJPB-plugins' site
// 4. Click 'Apply Changes' and restart ImageJ/Fiji

//Make separate image output folders for overlay and counts
	//Overlay
OverlayFolder = output + File.separator + "Tuj1_Overlay";
File.makeDirectory(OverlayFolder);
	//Counts
CountsFolder = output + File.separator + "Tuj1_Auto_Cell_Counts";
File.makeDirectory(CountsFolder);
	//Area
AreaFolder = output + File.separator + "Tuj1_Auto_Cell_Area";
File.makeDirectory(AreaFolder);
		// Make subdirectory in area for individual cell statistics
IndivMetricsFolder = AreaFolder + File.separator + "Tuj1_Individual_Cell_Metrics";
File.makeDirectory(IndivMetricsFolder);

// Make results summary excel spreadsheet
getDateAndTime(year, month, week, day, hour, min, sec, msec);
month=month+1;
summaryFilepath = output + File.separator +month+"."+day+"."+year+"_Tuj1_Cell_Count_Summary.xls";

// Initialize summary excel spreadsheet
summaryFile = File.open(summaryFilepath);
close(summaryFile);

// Spreadsheet Headers
spdsht = "Image Name\tCount\tTotal Area\tAverage Size\tPercent Area\n";
File.saveString(spdsht, summaryFilepath);


// Start Processing
processFolder(input);

// function to scan folder
function processFolder(input) {
	fileList = getFileList(input);
	fileList = Array.sort(fileList);
	for (i = 0; i < fileList.length; i++) {
		processFile(input, fileList[i], output);
	}
}

//Weka Tuj1 Automated Positive Cell Detection
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
	selectImage(xtifFileName+"-0004");
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
	classifierPath = homeDir + "/Box/Helen Lai Lab/Vihaan (HS Summer Intern)/Cell Counting Automation/Tuj1/Tuj1_Classifier.classifier";
	
	//Run Labkit
    run("Segment Image With Labkit", "segmenter_file=["+ classifierPath + "] use_gpu=false");

	Tuj1fileName = "Tuj1_"+fileName;
	rename(Tuj1fileName);

	// Post classification image processing
	selectImage(Tuj1fileName);
	postProcess();
	
	//Duplicate Image
	run("Duplicate...", " ");
	overlaydup = "Overlay-Dup_"+i;
	rename(overlaydup);
	run("Auto Local Threshold", "method=Phansalkar radius=30 parameter_1=0 parameter_2=0 white");
	run("Red");
	
	// Get Area Image
	selectImage(Tuj1fileName);
	run("Duplicate...", " ");
	areadup = "Area-Dup_"+i;
	rename(areadup);
	
	// Erode to split touching cells
	selectImage(Tuj1fileName);
	for (i=0;i<2;i++){
		run("Erode");
	}

	// Analyze particles FOR COUNT
	run("Analyze Particles...", "size=16-Infinity pixel show=[Overlay Masks] summarize");
	
	// Save some of the summary metrics into variables
	selectWindow("Summary");
	IJ.renameResults("Summary", "Results");
	cellCount = getResult("Count", 0);
    run("Clear Results");
    close("Results");

	//Save Count Image
	selectImage(Tuj1fileName);
	run("Grays");
	Autofilename = "Tuj1_Auto_Cell_Counts_" + fileName;
	saveAs("tiff", CountsFolder +File.separator+ Autofilename);
	
	// Area Process
	selectImage(areadup);
	areaProcess();

	// Analyze particles FOR AREA
	selectImage(areadup);
	run("Analyze Particles...", "size=16-Infinity pixel display summarize");
	
	// Save the individual cell results
	indivFilepath = IndivMetricsFolder + File.separator + "Tuj1_Indiv_Cells_" + xtifFileName + ".xls";

		// Spreadsheet Headers
	indivspdsht = "Image Name\tArea (pixels)\n";
	File.saveString(indivspdsht, indivFilepath);

		// Add in the data
	selectWindow("Results");
	for (i=0;i<nResults;i++) {
		indivArea = getResult("Area", i);
		File.append(i + "\t" + indivArea, indivFilepath);
	}
		// Clear and close results
    run("Clear Results");
	close("Results");
	
	// Save some of the summary metrics into variables
	selectWindow("Summary");
	IJ.renameResults("Summary", "Results");
	totalArea = getResult("Total Area", 0);
	avgSize = getResult("Average Size", 0);
	pctArea = getResult("%Area", 0);
    run("Clear Results");
    close("Results");

	//Save Area Image
	selectImage(areadup);
	Autoareafilename = "Tuj1_Auto_Cell_Area_" + fileName;
	saveAs("tiff", AreaFolder +File.separator+ Autoareafilename);

	//Make overlay image
	selectImage(rawimg);
	run("Add Image...", "image="+overlaydup+" x=0 y=0 opacity=33");
	Overlayfilename = "Tuj1_Cell_Counts_Overlay_" + fileName;
	saveAs("tiff", OverlayFolder +File.separator+ Overlayfilename);

    // Write the results to the summary file
    values = newArray(fileName, cellCount, totalArea, avgSize, pctArea);
	values = String.join(values, "\t");
	File.append(values, summaryFilepath);

	//Close everything (other than Log)
	clseimg = newArray(Autofilename,overlaydup,Overlayfilename, Autoareafilename, "Summary", areadup);
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

	close(xtifFileName+"-0002");
	close(xtifFileName+"-0003");
	close(xtifFileName+"-0001");
}

	//Image post-classification processing
function postProcess() {
	run("Auto Local Threshold", "method=Phansalkar radius=15 parameter_1=0 parameter_2=0 white");
	run("Remove Outliers...", "radius=16 threshold=50 which=Bright");
}

function areaProcess() {
	setBackgroundColor(0,0,0);

	//-------------------------------
	
	// Start batch mode
	
	run("ROI Manager...");

	
	selectImage(areadup);
	rename("raw");
	
	cores = "cores";
	
	run("Duplicate...", "title="+cores);
	
	run("Duplicate...", "title=2");
	
	//-------------------------------
	
	// Start processing
	
	run("32-bit");
	
	setAutoThreshold("IsoData dark no-reset");
	
	//run("Threshold...");
	
	run("Convert to Mask");
	
	run("Fill Holes");
	
	run("Minimum...", "radius=10");
	
	run("Create Selection");
	
	//-------------------------------
	
	roiManager("Add");
	
	roiManager("Select", 0);
	
	roiManager("Split");
	
	roiManager("Delete");
	
	setForegroundColor(0,0,0);
	
	roiManager("Select", 0);
	
	roiManager("Fill");
	
	roiManager("Select", 1);
	
	roiManager("Fill");
	
	roiManager("Select", 2);
	
	roiManager("Fill");
	
	roiManager("Select", 4);
	
	roiManager("Fill");
	
	run("Maximum...", "radius=10");
	
	run("Create Selection");
	
	//-------------------------------
	
	selectWindow(cores);
	
	run("Restore Selection");
	
	setForegroundColor(255,255,255);
	
	run("Fill", "slice");
	
	setBackgroundColor(0, 0, 0);
	
	run("Clear Outside");
	
	run("Select None");
	
	run("Convert to Mask");
	
	roiManager("Fill");
	
	//-------------------------------
	
	// End of processing
	
	run("Ultimate Points");
	
	selectImage("raw");
	
	run("Marker-controlled Watershed", "input=raw marker=" + cores + " mask=raw compactness=30 binary calculate use");
	
	setOption("ScaleConversions", true);
	
	run("8-bit");
	
	run("Auto Local Threshold", "method=Sauvola radius=15 parameter_1=0 parameter_2=0 white");
	rename(areadup);
	
	closewndws = newArray("2","ROI Manager", cores, "raw");
	for (i=0;i<closewndws.length;i++) {
		close(closewndws[i]);
	}
}
