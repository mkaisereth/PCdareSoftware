function status = ExtractFileFromZip(zipFilename, subDir, subFileStart, subFileEnd, outputDir, outputFile, doCheckSubfolder, doOverwrite)
% extractFile

% Create a stream copier to copy files.
streamCopier = com.mathworks.mlwidgets.io.InterruptibleStreamCopier.getInterruptibleStreamCopier;

% Create a Java zipFile object and obtain the entries.
try
    % Create a Java file of the Zip filename.
    zipJavaFile = java.io.File(zipFilename);

    % Create a java ZipFile and validate it.
    zipFile = org.apache.tools.zip.ZipFile(zipJavaFile);

    % Get entry
    entries = zipFile.getEntries();
    didFind = false;
    while entries.hasMoreElements
        entry = entries.nextElement;
        filelist = char(entry);
        subDirFileStart = subFileStart;
        if ~isempty(subDir)
            subDirFileStart = append(subDir, "/", subFileStart);
        end
        %disp(filelist)
        if startsWith(filelist, subDirFileStart) && endsWith(filelist, subFileEnd)
            % found
            didFind = true;
            break;
        end
        if ~isempty(doCheckSubfolder) &&...
                startsWith(filelist, append(doCheckSubfolder, "/" , subDirFileStart)) && endsWith(filelist, subFileEnd)
            % found
            didFind = true;
            break;
        end
    end

catch exception
    disp(append("Warning: zip failed: ", zipFilename));
    if exist("zipFile", 'var') && ~isempty(zipFile)
        zipFile.close;
    end
    return;
end

if ~didFind
    disp(append("Warning: ", subFileStart, "*", subFileEnd, "not found in ", zipFilename));
    zipFile.close;
    status = false;
    return
end

% Create the Java File output object using the entry's name.
if isempty(outputFile)
    filelistSplit = split(filelist, "/");
    outputFile = filelistSplit{end};
end
file = java.io.File(append(outputDir, "/", outputFile));

% If the parent directory of the entry name does not exist, then create it.
parentDir = char(file.getParent.toString);
if ~exist(parentDir, 'dir')
    mkdir(parentDir)
end

% check whether file already exists
if ~file.isFile || doOverwrite
    % Create an output stream
    try
        fileOutputStream = java.io.FileOutputStream(file);
    catch exception
        overwriteExistingFile = file.isFile && ~file.canWrite;
        if overwriteExistingFile
            warning(message('MATLAB:extractArchive:UnableToOverwrite', outputName));
        else
            warning(message('MATLAB:extractArchive:UnableToCreate', outputName));
        end
        return
    end
    
    % Create an input stream from the API
    fileInputStream = zipFile.getInputStream(entry);
    
    % Extract the entry via the output stream.
    streamCopier.copyStream(fileInputStream, fileOutputStream);
    
    % Close the output stream.
    fileOutputStream.close;
end
zipFile.close;
status = true;
end