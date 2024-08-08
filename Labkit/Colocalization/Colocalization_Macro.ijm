#@ File (label = "_SV image directory", style = "directory") input
#@ File (label = "Auto_cell_counts directory", style = "directory") output

//Make new folder in output folder titled 'Colocalization'
ColocFolder = output + File.separator + "Colocalization";
File.makeDirectory(ColocFolder);

// set batch mode
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
	
	// Open image and store image name in a variable img_name
	filePath = input + File.separator + filePath;
	open(filePath);
	img_name = getInfo("image.filename");
	close(img_name);

	//get_stain_names()
		// Get DAPI index
	DAPI_index = indexOf(img_name, "DAPI");

		// Extract stain 1
	stain_1_index = DAPI_index+5;
	stain_1 = img_name.substring(stain_1_index);
	stain_1 = stain_1.substring(0,indexOf(stain_1,"_"));

		// Extract stain 2
	stain_2_index = stain_1_index + lengthOf(stain_1) + 1;
	stain_2 = img_name.substring(stain_2_index);
	stain_2 = stain_2.substring(0,indexOf(stain_2,"_"));

		// Extract stain 3
	stain_3_index = stain_2_index + lengthOf(stain_2) + 1;
	stain_3 = img_name.substring(stain_3_index);
	index_underscore = indexOf(stain_3, "_");
	index_period = indexOf(stain_3, ".");
	if (index_underscore == -1) {
		index_underscore = Integer.MAX_VALUE; // if no underscore, set it to a large number
	}
	if (index_period == -1) {
		index_period = Integer.MAX_VALUE; // if no period, set it to a large number
	}
	end_index = Math.min(index_underscore, index_period);
	stain_3 = stain_3.substring(0, end_index);

	// Get the 3 replicates of the imgs for each stain with a for loop
	stainls = newArray(stain_1,stain_2,stain_3);
	
	for (i=0;i<3;i++) {
		stain_img_path = output + File.separator + stainls[i] + "_Auto_Cell_Counts" + File.separator + stainls[i] + "_Auto_Cell_Counts_" + img_name;
		print(stain_img_path);
		open(stain_img_path);
		rename("img"+(i+1));
		run("RGB Color");
	}

	//Make the image duplicates
	selectImage("img1");
	rename("img1_3");
	run("Duplicate...", " ");
	rename("img1_2");
	selectImage("img2");
	rename("img2_1");
	run("Duplicate...", " ");
	rename("img2_3");
	selectImage("img3");
	rename("img3_1");
	run("Duplicate...", " ");
	rename("img3_2");
	

	//Merge Channels and save for all of the stain combos
	run("Merge Channels...", "c1=img2_1 c2=img1_2 create keep");
	saveAs("tiff", ColocFolder + File.separator + stain_2 + "_" + stain_1 + "_"+ "Overlay_" + img_name);
	close("img1_2","img2_1");

	run("Merge Channels...", "c1=img3_1 c2=img1_3 create keep");
	saveAs("tiff", ColocFolder + File.separator + stain_3 + "_" + stain_1 + "_"+ "Overlay_" + img_name);
	close("img1_3","img3_1");

	run("Merge Channels...", "c1=img3_2 c2=img2_3 create keep");
	saveAs("tiff", ColocFolder + File.separator + stain_3 + "_" + stain_2 + "_"+ "Overlay_" + img_name);
	close("img2_3","img3_2");

	//Close all
	close("*");
}

print("All image overlays saved");
