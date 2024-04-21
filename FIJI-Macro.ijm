//Macro for pre-prosseting of obejcts imaged with apple rotator device.
//This macro is part of the bachelor thesis of Moritz Nelle
//Developed in 2023


var shareOfAll		= 103;
var numOfAll		= 103;

var masterCenterX	= 0;
var masterCenterY	= 0;
var imageN			= 0;
var correctionPath	= "G:/Bachelor_Thesis/Fiji_Macros/correction_file.tif";
var startMs;
var cropCenterX;
var cropCenterY;
print("\\Clear");
Dialog.create("Number of images to be analyzed");

macro "main_macro" {
	
	startUp();
	
	if (File.exists(correctionPath) != 1){
		print("Correction file was NOT found at default path: " + correctionPath);
		correctionPath = File.openDialog("Default dim corretion file could NOT be found. Please select one manually. Must be a .tif.");
		print("Correction file path manually set to: " + correctionPath);
	}else {
		print("Correction file was found at default path: " + correctionPath);
	}

	Dialog.addNumber("Share of all images: ", shareOfAll);
	Dialog.addNumber("Number all images: ", numOfAll);
	Dialog.show();
	shareOfAll = Dialog.getNumber();
	numOfAll = Dialog.getNumber();
	print("Total number of images to process: " + numOfAll);
	print("Share of all images to process: " + shareOfAll);
	var FilePath;
	var numFilePath;
	var storeStack;
	
	FilePath = File.openDialog("Choose the FIRST file. Must have an .img-ending and the number *_0000");

	print("First image to open: " + FilePath);
	
	for(imageN=0; imageN<shareOfAll; imageN++){ //rename 
		if(imageN<10){
			numFilePath = replace(FilePath, "0000", "000" + imageN);
			
			if(imageN==0){
				openAndReslice();
				setSlice(250);
				setTool(0);
				waitForUser("Select", "Please select your region of interest on the window prompt.\nUse only the selected rectangular tool.\nWhen selection done click OK.");
				Roi.getBounds(appleX, appleY, appleWidth, appleHeight);
				print("Apple area selected manually: X:" + appleX +" / Y:"+ appleY +" / Width:"+ appleWidth +" / Height:"+ appleHeight);

				close("Reslice of Original_" + File.getName(numFilePath));
				//determine original dot position and store it
			}
			
		}else{
			if (imageN>=10 && imageN<100) {
				numFilePath = replace(FilePath, "0000", "00" + imageN);
			}else {
				if (imageN>=100 && imageN<1000) {
					numFilePath = replace(FilePath, "0000", "0" + imageN);
				}else {
					showMessageWithCancel("ERROR", "This makro is unable to open more than 1000 images.")
				}
			}
		}
	
		//form here file with new FilePath
		openAndReslice();
	
		getDotXY();		
		
		run("Translate...", "x=0 y=0 interpolation=None stack");
		selectWindow("Reslice of Original_" + File.getName(numFilePath));
		makeRectangle(appleX, appleY, appleWidth, appleHeight);
		run("Crop");
		
	}//ends for "rename"
	
	run("Concatenate...", "all_open open");
	print("Concatenate all open images.");
	
	rename("Hyperstack_" + File.getName(numFilePath));
	
	cropToMin();
	print("Save: HSI Hyperstack"); 
	saveAs("Tiff", replace(FilePath, File.getName(FilePath), "\\Hyperstack_" + replace(File.getName (FilePath) ,"_0000","")));
	
	rollOut();
	print("Save: HSI Rollout"); 
	rename("Rollout");
	saveAs("Tiff", replace(FilePath, File.getName(FilePath), "\\Rollout_" + replace(File.getName (FilePath) ,"_0000","")));
	
	rolloutName = "Rollout_"+replace(File.getName (FilePath) ,"_0000.img",".tif");
	cosCorrection(getWidth(),getHeight(), rolloutName);
	print("Save: HSI Rollout Compensated"); 
	saveAs("Tiff", replace(FilePath, File.getName(FilePath), "\\Rollout_compensate_" + replace(File.getName (FilePath) ,"_0000","")));
	
	generateScyvenFile();
	print("Save: Scyven Image"); 
	saveAs("Raw Data", replace(FilePath, File.getName(FilePath), "\\Scyven_Image_" + replace(File.getName (FilePath) ,"_0000","")));
	
	
	close("*");
	
	openRGB();
	
	finishUp();
	
} //end of macro

//--------------------------------------------------------------------------


function openAndReslice(){
	run("Raw...", "open=" + numFilePath + " image=[16-bit Unsigned] width=501 height=480 number=640 little-endian");
	rename("Original_" + File.getName(numFilePath));
	run("Reslice [/]...", "output=1.000 start=Left avoid");
	rename("Reslice of Original_" + File.getName(numFilePath));
	close("Original_" + File.getName(numFilePath));
}


function getDotXY() {
	run("Duplicate...", "ignore duplicate range=177-177");
	rename("Temp " + imageN);
	makeOval(appleX, appleY, appleWidth, appleHeight);
	//run("Clear");
	setThreshold(35000, 65535, "raw");
	run("Convert to Mask", "method=Default background=Dark black");
	run("Clear Results");
	run("Analyze Particles...", "size=430-800 circularity=0.80-1.00 display exclude overlay add");
//	stop;
	getCentroidFromROI();
	
	//close("Reslice of Original_" + File.getName(numFilePath));
}


function getCentroidFromROI(){  

	var translateX = 0;
	var translateY = 0;
	
	if(roiManager("count")!=4){
		print("ERROR (slice " + imageN + "): did not found 4 ROIs"); 
	}else{
		
		for (i = 0; i < roiManager("count"); i++) {
			roiManager("select", i)
			Roi.getCoordinates(xpoints, ypoints);
			//print("Selection " + i+1 + ": " + xpoints[i] + "/" + ypoints[i]);
			translateX = translateX + xpoints[i];
			translateY = translateY + ypoints[i];
		}		
		if(imageN == 0){
			masterCenterX = translateX / roiManager("count");
			masterCenterY = translateY / roiManager("count");
				print("Master Center (Slice 0) X = " + masterCenterX);
				print("Master Center (Slice 0) Y = " + masterCenterY);
		}else {
			
			translateX = (translateX / roiManager("count")) - masterCenterX;
			translateY = (translateY / roiManager("count")) - masterCenterY;
			print("Slice " + imageN + "/" + shareOfAll-1 + " translate: " + translateX + " / " + translateY);
			selectWindow("Reslice of Original_" + File.getName(numFilePath));
			run("Translate...", "x=" + -translateX + " y=" + -translateY + " interpolation=Bicubic stack");
			close("Temp " + imageN); //closes sucessfull Particle mask
		}
	}
 	close("Temp " + imageN); //closes failed Particle mask and master-mask
	roiManager("reset");
}


function rollOut(){
	print("Rollout HSI"); 
	HyperstackID = getImageID();
	var sliceWidth = ((getWidth()*3.14159)/numOfAll)/**(getHeight()/getWidth())*/;
	makeRectangle((getWidth()/2)-40, 0, (sliceWidth), getHeight());

	for (i = 0; i < shareOfAll; i++) {
		selectImage(HyperstackID);
		run("Duplicate...", "duplicate frames=" + i+1);
		rename(i);
		
		if(i>0){
			run("Combine...", "stack1=[" + i + "] stack2=[" + i-1 + "]");
			rename(i);
		}
	}
}

function cosCorrection(x,y, toCompensate){
	print("Cos Correction");
	open(correctionPath);
	rename("Correction Image");
	run("Size...", "width=" + x + " height=" + y + " depth=1 interpolation=Bicubic");
	imageCalculator("Divide create 32-bit stack", toCompensate,"Correction Image");
}


function cropToMin(){
	print("Crop to Min"); 
	setTool(0);
	//setSlice(260);
	doCommand("Start Animation [\\]"); //starts rotation
	waitForUser("Select", "Please select your region of interest on the window promt.\nWhen selection done click OK.");
	
	Roi.getBounds(X, Y, Width, Height);
	print("Minimal apple area selected manually: X:" + X +" / Y:"+ Y +" / Width:"+ Width +" / Height:"+ Height);

	temp = getImageID();
	run("Duplicate...", "duplicate");
	selectImage(temp);
	close;
}


function openRGB(){
	
	print("open RGB"); 
	
	for(imageN=0; imageN<shareOfAll; imageN++){ //rename 
	if(imageN<10){
		numFilePath = replace(FilePath, "0000", "000" + imageN);
	}else{
		if (imageN>=10 && imageN<100) {
			numFilePath = replace(FilePath, "0000", "00" + imageN);
		}else {
			if (imageN>=100 && imageN<1000) {
				numFilePath = replace(FilePath, "0000", "0" + imageN);
			}else {
				showMessageWithCancel("ERROR", "This makro is unable to open more than 1000 images.")
			}
		}
	}
		open(replace(numFilePath, ".img", ".png"));
		rename("RGB_" + File.getName(numFilePath));
		//run("Gamma...", "value=0.4");
		run("Rotate 90 Degrees Right");
		run("Flip Horizontally");
		run("Size...", "width=480 height=640 depth=1 average interpolation=Bicubic");
		makeRectangle(appleX*0.95, appleY*0.85, appleWidth*1.1, appleHeight*1.1);
		run("Crop");
	}//ends for "rename"
	
	run("Concatenate...", "all_open open");
	cropToMin();
	
	print("Save: RGB Image");
	saveAs("Tiff", replace(FilePath, File.getName(FilePath), "\\Image_RGB_" + replace(File.getName (FilePath) ,"_0000","")));
	
	RGBID = getImageID();
//	makeRectangle((getWidth()/2)-40, 0, (getWidth()/50), getHeight());
	var sliceWidth = ((getWidth()*3.14159)/numOfAll)/**(getHeight()/getWidth())*/;
	makeRectangle((getWidth()/2)-40, 0, (sliceWidth), getHeight());
	print("Rollout RGB");

	for (i = 0; i < shareOfAll; i++) {
		selectImage(RGBID);
		setSlice(i+1);
		run("Duplicate...", " ");
		rename(i);
		
		if(i>0){
			run("Combine...", "stack1=[" + i + "] stack2=[" + i-1 + "]");
			rename(i);
		}
	}
	print("Save: RGB Rollout"); 
	saveAs("Tiff", replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_" + replace(File.getName (FilePath) ,"_0000","")));	

	run("RGB Stack");
	rename("RGB_Stack");
	
	print("Save: RGB Rollout Stack"); 
	saveAs("Tiff", replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_Stack_" + replace(File.getName (FilePath) ,"_0000","")));
	
	RGBStackName = "Rollout_RGB_Stack_" + replace(File.getName (FilePath) ,"_0000.img",".tif");
	cosCorrection(getWidth(), getHeight(), RGBStackName);
	
	run("Multiply...", "value=256 stack"); //Compensate for dividing an 8-bit image by an 16-bit image
	
	rename("RGB_stack_compensated");
	
	print("Save: RGB Rollout Stack compensated"); 
	saveAs("Tiff", replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_Stack_compensated_" + replace(File.getName (FilePath) ,"_0000","")));

	resetMinAndMax;
	getMinAndMax(min, max);
	setMinAndMax(min, max);
	run("16-bit");
	run("Stack to RGB");

	saveAs("Tiff", replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_compensated_" + replace(File.getName (FilePath) ,"_0000","")));
}


function startUp(){
	saveSettings();	//restore all settings 
	close("*");
	run("Clear Results");
	startMs = getTime();
	roiManager("reset");
}

function generateScyvenFile(){
	print("Generate Scyven image");
	run("Reslice [/]...", "output=1.000 start=Right avoid");
	resetMinAndMax;
	getMinAndMax(min, max);
	setMinAndMax(min, max);
	setOption("ScaleConversions", true);
	run("16-bit");
	run("Rotate 90 Degrees Left");
	generateHdrFile(getWidth(), getHeight(), nSlices);
}

function generateHdrFile(bands, samples, lines){
	
	if(File.exists(replace(FilePath, File.getName(FilePath), "\\Scyven_Image_" + replace(File.getName (FilePath) ,"_0000.img","") + ".hdr"))==1){
		File.delete(replace(FilePath, File.getName(FilePath), "\\Scyven_Image_" + replace(File.getName (FilePath) ,"_0000.img","") + ".hdr"))
		print("Detected HDR file with similar name. Detected file got deleted.");
	}
		
	file = File.open(replace(FilePath, File.getName(FilePath), "\\Scyven_Image_" + replace(File.getName (FilePath) ,"_0000.img","") + ".hdr"));
	print(file, "ENVI\ndescription = {\n   - [2023-05-03 14:32:08.735481] -  - }\nsamples = "+samples+"\nlines = "+lines+"\nbands = "+bands+"\nheader offset = 0\nfile type = ENVI Standard\ndata type = 12\ninterleave = bip\nbyte order = 0\nwavelength = { 500 , 501 , 502 , 503 , 504 , 505 , 506 , 507 , 508 , 509 , 510 , 511 , 512 , 513 , 514 , 515 , 516 , 517 , 518 , 519 , 520 , 521 , 522 , 523 , 524 , 525 , 526 , 527 , 528 , 529 , 530 , 531 , 532 , 533 , 534 , 535 , 536 , 537 , 538 , 539 , 540 , 541 , 542 , 543 , 544 , 545 , 546 , 547 , 548 , 549 , 550 , 551 , 552 , 553 , 554 , 555 , 556 , 557 , 558 , 559 , 560 , 561 , 562 , 563 , 564 , 565 , 566 , 567 , 568 , 569 , 570 , 571 , 572 , 573 , 574 , 575 , 576 , 577 , 578 , 579 , 580 , 581 , 582 , 583 , 584 , 585 , 586 , 587 , 588 , 589 , 590 , 591 , 592 , 593 , 594 , 595 , 596 , 597 , 598 , 599 , 600 , 601 , 602 , 603 , 604 , 605 , 606 , 607 , 608 , 609 , 610 , 611 , 612 , 613 , 614 , 615 , 616 , 617 , 618 , 619 , 620 , 621 , 622 , 623 , 624 , 625 , 626 , 627 , 628 , 629 , 630 , 631 , 632 , 633 , 634 , 635 , 636 , 637 , 638 , 639 , 640 , 641 , 642 , 643 , 644 , 645 , 646 , 647 , 648 , 649 , 650 , 651 , 652 , 653 , 654 , 655 , 656 , 657 , 658 , 659 , 660 , 661 , 662 , 663 , 664 , 665 , 666 , 667 , 668 , 669 , 670 , 671 , 672 , 673 , 674 , 675 , 676 , 677 , 678 , 679 , 680 , 681 , 682 , 683 , 684 , 685 , 686 , 687 , 688 , 689 , 690 , 691 , 692 , 693 , 694 , 695 , 696 , 697 , 698 , 699 , 700 , 701 , 702 , 703 , 704 , 705 , 706 , 707 , 708 , 709 , 710 , 711 , 712 , 713 , 714 , 715 , 716 , 717 , 718 , 719 , 720 , 721 , 722 , 723 , 724 , 725 , 726 , 727 , 728 , 729 , 730 , 731 , 732 , 733 , 734 , 735 , 736 , 737 , 738 , 739 , 740 , 741 , 742 , 743 , 744 , 745 , 746 , 747 , 748 , 749 , 750 , 751 , 752 , 753 , 754 , 755 , 756 , 757 , 758 , 759 , 760 , 761 , 762 , 763 , 764 , 765 , 766 , 767 , 768 , 769 , 770 , 771 , 772 , 773 , 774 , 775 , 776 , 777 , 778 , 779 , 780 , 781 , 782 , 783 , 784 , 785 , 786 , 787 , 788 , 789 , 790 , 791 , 792 , 793 , 794 , 795 , 796 , 797 , 798 , 799 , 800 , 801 , 802 , 803 , 804 , 805 , 806 , 807 , 808 , 809 , 810 , 811 , 812 , 813 , 814 , 815 , 816 , 817 , 818 , 819 , 820 , 821 , 822 , 823 , 824 , 825 , 826 , 827 , 828 , 829 , 830 , 831 , 832 , 833 , 834 , 835 , 836 , 837 , 838 , 839 , 840 , 841 , 842 , 843 , 844 , 845 , 846 , 847 , 848 , 849 , 850 , 851 , 852 , 853 , 854 , 855 , 856 , 857 , 858 , 859 , 860 , 861 , 862 , 863 , 864 , 865 , 866 , 867 , 868 , 869 , 870 , 871 , 872 , 873 , 874 , 875 , 876 , 877 , 878 , 879 , 880 , 881 , 882 , 883 , 884 , 885 , 886 , 887 , 888 , 889 , 890 , 891 , 892 , 893 , 894 , 895 , 896 , 897 , 898 , 899 , 900 , 901 , 902 , 903 , 904 , 905 , 906 , 907 , 908 , 909 , 910 , 911 , 912 , 913 , 914 , 915 , 916 , 917 , 918 , 919 , 920 , 921 , 922 , 923 , 924 , 925 , 926 , 927 , 928 , 929 , 930 , 931 , 932 , 933 , 934 , 935 , 936 , 937 , 938 , 939 , 940 , 941 , 942 , 943 , 944 , 945 , 946 , 947 , 948 , 949 , 950 , 951 , 952 , 953 , 954 , 955 , 956 , 957 , 958 , 959 , 960 , 961 , 962 , 963 , 964 , 965 , 966 , 967 , 968 , 969 , 970 , 971 , 972 , 973 , 974 , 975 , 976 , 977 , 978 , 979 , 980 , 981 , 982 , 983 , 984 , 985 , 986 , 987 , 988 , 989 , 990 , 991 , 992 , 993 , 994 , 995 , 996 , 997 , 998 , 999 , 1000 }\nwavelength units = nm\nexposure = 66\ngain = 0\nanaloggain = 1");
 	File.close(file);
}

function finishUp(){
	close("*"); //close all image windows
	
	print(replace(FilePath, File.getName(FilePath), "\\Hyperstack_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	print(replace(FilePath, File.getName(FilePath), "\\Rollout_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	print(replace(FilePath, File.getName(FilePath), "\\Rollout_compensate_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	print(replace(FilePath, File.getName(FilePath), "\\Image_RGB_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	print(replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	print(replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_Stack_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	print(replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_Stack_compensated_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	print(replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_compensated_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	print(replace(FilePath, File.getName(FilePath), "\\Scyven_Image_" + replace(File.getName (FilePath) ,"_0000.img","") + ".raw"));
	
	open(replace(FilePath, File.getName(FilePath), "\\Hyperstack_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	open(replace(FilePath, File.getName(FilePath), "\\Rollout_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	open(replace(FilePath, File.getName(FilePath), "\\Rollout_compensate_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	resetMinAndMax;
	getMinAndMax(min, max);
	setMinAndMax(min, max);
	open(replace(FilePath, File.getName(FilePath), "\\Image_RGB_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	open(replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	open(replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_Stack_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	open(replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_Stack_compensated_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));	
	open(replace(FilePath, File.getName(FilePath), "\\Rollout_RGB_compensated_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	//open(replace(FilePath, File.getName(FilePath), "\\Scyven_Image_" + replace(File.getName (FilePath) ,"_0000.img","") + ".tif"));
	
	restoreSettings;
	print("Settings restored.");
	
	print ("Job Done in " + ((getTime()-startMs)/60000) + " Minutes");
	selectWindow("Log");
	saveAs("Text", replace(FilePath, File.getName(FilePath), "\\Macro-Log_" + replace(File.getName (FilePath) ,"_0000","")));
	print("Log saved (without this line)");
	showMessage("Jod Done!");
}