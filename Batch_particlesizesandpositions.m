clc;
clear;

% Input and output directories
inputDir = '/Users/arbot/Documents/MATLAB/Image Analysis/ImageCase'; % Replace with your folder path
outputDir = '/Users/arbot/Documents/MATLAB/Image Analysis/ImageCase/results';  % Replace with your folder path

filePath = fullfile(inputDir, 'AllParticleDiameters.txt');

if ~isfolder(outputDir)
    mkdir(outputDir); % Create output directory if it doesn't exist
end

% Get list of all .tif files in the input directory
fileList = dir(fullfile(inputDir, '*.tif'));

%loop to process each image
for k = 1:length(fileList)
    try
        % File paths
        inputFile = fullfile(inputDir, fileList(k).name);
        outputSubDir = fullfile(outputDir, fileList(k).name(1:end-4));
        if ~isfolder(outputSubDir)
            mkdir(outputSubDir); % Create subfolder for each image
        end

        % Load the image
        img = imread(inputFile);

        % Display and save original image
        fig1 = figure('Visible', 'off');
        imshow(img);
        title('Original Image');
        saveas(fig1, fullfile(outputSubDir, 'Original_Image.png'));
        h = imline; % Allows the user to draw a line on the image interactively

        % Scale calculation
        
        position = wait(h);
        x1 = position(1,1);
        y1 = position(1,2);
        x2 = position(2,1);
        y2 = position(2,2);

         % User-defined known length
        % knownLength = input('Enter the known real-world length in nm: '); % Set your real-world length in nm
        prompt = {'Enter the known real-world length in nm:'};
        dlgTitle = 'Input Required';
        numLines = 1; % Number of lines in the input field
        defaultAnswer = {'100'}; % Default value

        % Display the dialog box
        answer = inputdlg(prompt, dlgTitle, numLines, defaultAnswer);
        
        % Convert the input (if necessary)
        if ~isempty(answer) % Check if user did not cancel
            knownLength = str2double(answer{1}); % Convert string to number
            fprintf('Known length entered: %.2f nm\n', knownLength);
        else
            disp('User canceled the input dialog.');
        end

        lengthInPixels = sqrt((x2 - x1)^2 + (y2 - y1)^2);
        pixelToRealWorldScale = knownLength / lengthInPixels;
        close(fig1);
        % Annotate line on image
        fig2 = figure('Visible', 'off');
        imshow(img);
        hold on;
        plot([x1, x2], [y1, y2], 'r-', 'LineWidth', 2);
        text(mean([x1, x2]), mean([y1, y2]), sprintf('%.2f px', lengthInPixels), ...
            'Color', 'yellow', 'FontSize', 12, 'FontWeight', 'bold');
        hold off;
        title('Line Measurement');
        saveas(fig2, fullfile(outputSubDir, 'Line_Measurement.png'));
        close(fig2);

        % Crop and convert to grayscale
        figure, imshow(img), title('Select a region to crop');
    
        % Prompt the user to crop the image
        disp('Use the mouse to select a region to crop, then double-click.');
        croppedImage = imcrop(img); % User selects the cropping region
        grayImg = rgb2gray(croppedImage);

        % Threshold and edge detection
        threshold = 50;
        binaryImg = grayImg < threshold;
        edges = edge(binaryImg, 'canny');

        % Morphological cleaning
        se = strel('disk', 2);
        cleanEdges = imclose(edges, se);
        cleanEdges = bwareaopen(cleanEdges, 50);
        filledObjects = imfill(cleanEdges, 'holes');

        % Save cleaned edges and filled objects
        fig3 = figure('Visible', 'off');
        imshow(cleanEdges);
        title('Cleaned Edges');
        saveas(fig3, fullfile(outputSubDir, 'Cleaned_Edges.png'));
        close(fig3);

        fig4 = figure('Visible', 'off');
        imshow(filledObjects);
        title('Filled Objects');
        saveas(fig4, fullfile(outputSubDir, 'Filled_Objects.png'));
        close(fig4);

        % Object detection and statistics
        [labeledImage, numObjects] = bwlabel(filledObjects);
        stats = regionprops(labeledImage, 'Area', 'Centroid');
        Areas = [stats.Area]';
        diameters = sqrt(4 / pi * Areas);
        diametersinnm = diameters * pixelToRealWorldScale;
        averageDiameter = mean(diametersinnm);

        % Save histogram
        fig5 = figure('Visible', 'off');
        histogram(diametersinnm);
        title('Histogram of Object Sizes');
        xlabel('Diameter (nm)');
        ylabel('Frequency');
        grid on;
        saveas(fig5, fullfile(outputSubDir, 'Histogram.png'));
        close(fig5);

        % Save results
        resultsFile = fullfile(outputSubDir, 'Results.mat');
        save(resultsFile, 'Areas', 'diameters', 'diametersinnm', 'averageDiameter', 'numObjects');
        
        exportArea = zeros(numObjects,1);
        exportCentroids = zeros(numObjects,2);
        exportDiamnm= zeros(numObjects,1);
        exportAvgDiam=zeros(1,1);
        exportnumObj=zeros(1,1);

        for i = 1:numObjects
         exportCentroids(i,1:2) = stats(i).Centroid;


         fileID = fopen(filePath, 'a');
             if fileID == -1
             error('Failed to open the file.');
             end

         fprintf(fileID, '%f\n', diametersinnm(i, :));
        fclose(fileID);
        end

        exportArea = [Areas];
        exportDiamnm = [diametersinnm];
        exportAvgDiam = [averageDiameter];
        exportnumObj = [numObjects];

        % Define output .txt file
        % outputFile1 = fullfile(outputSubDir, 'exported_Area.txt');
        % outputFile2 = fullfile(outputSubDir, 'exported_Centroids.txt');
        outputFile3 = fullfile(outputSubDir, 'exported_Diameter_nm.txt');
        outputFile4 = fullfile(outputSubDir, 'exported_Average_diameter.txt');
        outputFile5 = fullfile(outputSubDir, 'exported_numObjects.txt');

        % Write data to .txt file
        % writematrix(exportArea, outputFile1, 'Delimiter', '\t');
        % writematrix(exportCentroids, outputFile2, 'Delimiter', '\t');
        writematrix(exportDiamnm, outputFile3, 'Delimiter', '\t');
        writematrix(exportAvgDiam, outputFile4, 'Delimiter', '\t');
        writematrix(exportnumObj, outputFile5, 'Delimiter', '\t');
        
        


        % Logging
        fprintf('Processed %s successfully.\n', fileList(k).name);
    catch ME
        % Log any errors for this file
        fprintf('Error processing %s: %s\n', fileList(k).name, ME.message);
    end
    close all;
end

AllDiamsinFolder = readmatrix(filePath);
AverageofAll = mean(AllDiamsinFolder);

fig6 = figure('Visible', 'off');
        histogram(AllDiamsinFolder);
        title('Histogram of Object Sizes. Average size is:', num2str(AverageofAll));
        xlabel('Diameter (nm)');
        ylabel('Frequency');
        grid on;
        saveas(fig6, fullfile(inputDir, 'HistogramOfAll.png'));
close(fig6);


disp('Batch processing complete!');
