function [ ttxImportMatter ] = importMatterData(sTarget)
%IMPORTMATTERDATA Import function that handles substance data import
%   Imports from either individual substances files or the MatterData.csv
%   file. It is HIGHLY specialized and adapted to the current format of the
%   .csv file. If this file and especially the arrangement of headers and
%   columns is changed in any way, this function needs to be substantially
%   changed. Several values are hard-coded here, like the number of text
%   columns and the overall width of the matter data table.
%
%   If there are individual data files for substances that are also listed
%   in the MatterData.csv file, the previously imported data from
%   MatterData.csv will be overwritten.
%
%   MatterImport returns
%   ttxImportMatter - struct with all data for a single substance or
%                     for all substances in MatterData.csv
%   Input parameters:
%   sTarget: 'MatterData' if matter data file is to be imported, or the
%            name of an individual substance (e.g. 'H2O'). If substance
%            name is given, both isochoric and isobaric data will be
%            imported.


%% Import data from MatterData.csv file
if strcmp(sTarget, 'MatterData')
    % At first we'll just read the first line of the file, this determines
    % the width of the actual table. So if more data columns are added in
    % the future, this code won't have to change so much.
    
    % Open the file
    iFileID = fopen(strrep('lib/+matterdata/MatterData.csv','/',filesep), 'r');
    % Get first row
    csFirstRow = textscan(iFileID, '%s', 1, 'Delimiter', '\n');
    % This is a cell array of cells, so we 'unpack' one level to get the
    % actual string.
    csFirstRow = csFirstRow{1};
    sFirstRow  = csFirstRow{1};
    
    csColumnNames = textscan(sFirstRow, '%s','Delimiter',',');
    csColumnNames = csColumnNames{1};
    
    for iI = 1:length(csColumnNames)
        if strcmp(csColumnNames{iI},'')
            csColumnNames(iI) = [];
        end
    end
    
    iNumberOfColumns = length(csColumnNames);
    
    % Getting the second row
    csSecondRow = textscan(iFileID, '%s', 1, 'Delimiter', '\n');
    % This is a cell array of cells, so we 'unpack' one level to get the
    % actual string.
    csSecondRow = csSecondRow{1};
    sSecondRow  = csSecondRow{1};
    
    csVariableNames = textscan(sSecondRow, '%s', iNumberOfColumns, 'Delimiter',',');
    csVariableNames = csVariableNames{1};
    
    for iI = 1:length(csVariableNames)
        if strcmp(csVariableNames{iI},'')
            csVariableNames(iI) = [];
        end
    end
    
    % Getting the third row
    csThirdRow = textscan(iFileID, '%s', 1, 'Delimiter', '\n');
    % This is a cell array of cells, so we 'unpack' one level to get the
    % actual string.
    csThirdRow = csThirdRow{1};
    sThirdRow  = csThirdRow{1};
    
    csUnits = textscan(sThirdRow, '%s', iNumberOfColumns, 'Delimiter',',');
    csUnits = csUnits{1};
    
    for iI = 1:length(csUnits)
        if strcmp(csUnits{iI},'')
            csUnits(iI) = [];
        end
    end
    
    sFormatString = '';
    
    for iI = 1:length(csColumnNames)
        sFormatString = strcat(sFormatString, '%s');
    end
    
    sFormatString = strcat(sFormatString, '%[^\n\r]');
    
    % Get all other rows
    csImportCell = textscan(iFileID, sFormatString, 'Delimiter', ',', 'ReturnOnError', false);
    
    %% Close the text file.
    fclose(iFileID);
    
    %% Convert the contents of columns containing numeric strings to numbers.
    % Replace non-numeric strings with NaN.
    % Creating a cell the size of the actual table, since the textscan
    % command above output a 1-D array of cells.
    csRawData = repmat({''},length(csImportCell{1}),length(csImportCell)-1);
    % Copying the data from the imported cell into the raw data cell
    for iFirstVariableColumn = 1:length(csImportCell)-1
        csRawData(1:length(csImportCell{iFirstVariableColumn}),iFirstVariableColumn) = csImportCell{iFirstVariableColumn};
    end
    % Creating an array full of NaNs
    afNumericData = NaN(size(csImportCell{1},1),size(csImportCell,2)-1);
    
    % The first three columns are text, so we just have to look at the
    % columns 4 and later
    for iFirstVariableColumn = 4:length(csImportCell)-1
        % Converts strings in the input cell array to numbers. Replaced non-numeric
        % strings with NaN.
        % First we create a cell with just the one column we are currently
        % looking at
        csRawDataColumn = csImportCell{iFirstVariableColumn};
        % Now we go through each of the rows and check, if the value in the
        % individual element is numeric or not.
        for iRow=1:size(csRawDataColumn, 1);
            % Create a regular expression to detect and remove non-numeric prefixes and
            % suffixes.
            sRegularExpression = '(?<prefix>.*?)(?<numbers>([-]*(\d+[\,]*)+[\.]{0,1}\d*[eEdD]{0,1}[-+]*\d*[i]{0,1})|([-]*(\d+[\,]*)*[\.]{1,1}\d+[eEdD]{0,1}[-+]*\d*[i]{0,1}))(?<suffix>.*)';
            tResult  = regexp(csRawDataColumn{iRow}, sRegularExpression, 'names');
            if isempty(tResult)
                afNumericData(iRow, iFirstVariableColumn) = NaN;
                csRawData{iRow, iFirstVariableColumn} = [];
                continue;
            else
                sNumbers = tResult.numbers;
            end
            
            % Detected commas in non-thousand locations.
            bInvalidThousandsSeparator = false;
            if any(sNumbers==',');
                sThousandsRegExp = '^\d+?(\,\d{3})*\.{0,1}\d*$';
                if isempty(regexp(sThousandsRegExp, ',', 'once'));
                    sNumbers = NaN;
                    bInvalidThousandsSeparator = true;
                end
            end
            % Convert numeric strings to numbers.
            if ~bInvalidThousandsSeparator;
                csNumbers = textscan(strrep(sNumbers, ',', ''), '%f');
                afNumericData(iRow, iFirstVariableColumn) = csNumbers{1};
                csRawData{iRow, iFirstVariableColumn} = csNumbers{1};
            end
        end
    end
    
    
    %% Split data into numeric and cell columns.
    %cfRawNumericColumns = csRawData(:, 4:length(csImportCell)-1);
    csRawStringColumns  = csRawData(:, 1:3);
    
    
%     %% Replace non-numeric cells with NaN
%     % This was in the automatically generated code for csv import. Don't
%     know if we really need this...
%     R = cellfun(@(x) ~isnumeric(x) && ~islogical(x),cfRawNumericColumns); % Find non-numeric cells
%     cfRawNumericColumns(R) = {NaN}; % Replace non-numeric cells
    
    
    % Storing the column of the melting point
    % ("codename" of first property to store in phase) to
    % save all properties. The properties to the left of
    % melting point are considered constant and independent of
    % phase, temperature, pressure, etc.
    % NOTE: Currently there is only one constant property,
    % which is molar mass. We are leaving this in here though
    % just in case another constant property is added in the
    % future.
    iFirstVariableColumn = find(strcmp(csVariableNames,'fMeltPoint'));
    
    % Initialize the struct in which all substances are later stored
    ttxImportMatter = struct();
    
    % To improve the matter table performance, by avoinding frequent calls
    % find() to get the column indices, we add a struct with the property
    % names as keys and their indices in the ttxMatter struct as values.
    % While we're at it, we'll also create a struct containing the units.
    
    % First create the empty structs
    tColumns = struct();
    tUnits   = struct();
    
    % Field names have to be without whitespace, so we remove it here
    csColumnNames = strrep(csColumnNames,' ','');
    
    % Now we go through all columns and create the key/value pairs for the
    % column names and units accordingly
    for iI = 1:iNumberOfColumns
        tColumns.(csColumnNames{iI}) = iI;
        tUnits.(csColumnNames{iI})   = csUnits{iI};
    end
    
    csSubstances = csRawStringColumns(:,1);
    
    % go through all substances
    for iI = 1:length(csSubstances)
        % Since there can be multiple rows for a substance, we'll check if
        % we already did this one and skip the rest if we did. 
        if isfield(ttxImportMatter,csSubstances{iI})
            continue;
        end
        
        % set substancename as fieldname
        ttxImportMatter.(csSubstances{iI}) = [];
        
        % select all rows of that substance
        % substances can have more than one phase
        aiRows = find(strcmp(csSubstances,csSubstances{iI}));
        
        if ~isempty(aiRows)
            % Store all data of current substance in the sub-struct of
            % ttxImportMatter.
            
            % Store the full name of the substance
            ttxImportMatter.(csSubstances{iI}).sName = csRawData{aiRows(1), 2};
            
            % Go through all constant properties before the melting point.
            % These properties do not change if the phase is different, so
            % we only need to import them once. We start at index 4,
            % because the first three columns are text entries.
            for iJ = 4:iFirstVariableColumn-1
                
                % Get the value of the property and save it to a variable.
                fValue = csRawData{aiRows(1), iJ};
                
                % Only handle numeric fields.
                if ~isnan(fValue)
                    % Finally we can write the value to the appropriate
                    % struct item.
                    ttxImportMatter.(csSubstances{iI}).(csVariableNames{iJ}) = fValue;
                else
                    ttxImportMatter.(csSubstances{iI}).(csVariableNames{iJ}) = [];
                end
                
            end
            
            tStructFieldNames        = struct();
            tStructFieldNames.solid  = 'tSolid'; 
            tStructFieldNames.liquid = 'tLiquid'; 
            tStructFieldNames.gas    = 'tGas';
            
            % go through all phases and save all remaining properties for that specific phase
            for iJ = 1:length(aiRows)
                for iK = iFirstVariableColumn:iNumberOfColumns
                    ttxImportMatter.(csSubstances{iI}).ttxPhases.(tStructFieldNames.(csRawData{aiRows(iJ),3})).(csColumnNames{iK}) = csRawData{aiRows(iJ),iK};
                end
            end
            
            % Since none of the substances in the "Matter Data" worksheet
            % will enable interpolation of their properties, we can just
            % set the variable to false here.
            %TODO Might not need this, so commented, remove if sure. 
            %ttxImportMatter.(csSubstances{iI}).bInterpolations = false;
            
            % Finally we add the tColumns and tUnits structs to every 
            % substance
            ttxImportMatter.(csSubstances{iI}).tColumns = tColumns;
            ttxImportMatter.(csSubstances{iI}).tUnits   = tUnits;
        end
    end
    %% import specific substance file
else
    
    % Initialize the struct in which all substance information is later stored
    ttxImportMatter = struct();
    
    % Read Info file
    iFileID = fopen(strrep(['lib/+matterdata/',sTarget,'_Information_File.csv'], '/', filesep));
    csInput = textscan(iFileID, '%s', 'Delimiter','\n');
    csInput = csInput{1};
    sInput_1 = csInput{1};
    sInput_2 = csInput{2};
    sInput_3 = csInput{3};
    sInput_4 = csInput{4};
    
    csColumnNames = textscan(sInput_1,'%s','Delimiter',',');
    csColumnNames = csColumnNames{1};
    
    csVariableNames = textscan(sInput_2,'%s','Delimiter',',');
    csVariableNames = csVariableNames{1};
    
    csUnits = textscan(sInput_3,'%s','Delimiter',',');
    csUnits = csUnits{1};
    
    csValues = textscan(sInput_4,'%s','Delimiter',',');
    csValues = csValues{1};
    
    fclose(iFileID);
    
    % The csValues struct may contain numeric and string values. We need to
    % tell both apart, so we'll do all of the following to figure it out.
    
    for iI=1:length(csValues);
        % Create a regular expression to detect and remove non-numeric prefixes and
        % suffixes.
        sRegularExpression = '(?<prefix>.*?)(?<numbers>([-]*(\d+[\,]*)+[\.]{0,1}\d*[eEdD]{0,1}[-+]*\d*[i]{0,1})|([-]*(\d+[\,]*)*[\.]{1,1}\d+[eEdD]{0,1}[-+]*\d*[i]{0,1}))(?<suffix>.*)';
        tResult  = regexp(csValues{iI}, sRegularExpression, 'names');
        if isempty(tResult)
            continue;
        else
            sNumbers = tResult.numbers;
        end
        
        % Detected commas in non-thousand locations.
        bInvalidThousandsSeparator = false;
        if any(sNumbers==',');
            sThousandsRegExp = '^\d+?(\,\d{3})*\.{0,1}\d*$';
            if isempty(regexp(sThousandsRegExp, ',', 'once'));
                sNumbers = NaN;
                bInvalidThousandsSeparator = true;
            end
        end
        % Convert numeric strings to numbers.
        if ~bInvalidThousandsSeparator;
            csNumbers = textscan(strrep(sNumbers, ',', ''), '%f');
            csValues{iI} = csNumbers{1};
        end
    end
    
    % Create entries in ttxImportMatter struct
    for iI = 1:length(csColumnNames)
        ttxImportMatter.(csVariableNames{iI}) = csValues{iI};
        ttxImportMatter.([csVariableNames{iI},'_Unit']) = csUnits{iI};
    end
    
    % To quickly indentify this as a substance with and individual data
    % file (instead of containing data from the MatterData.csv file), we
    % set a boolean variable here.
    ttxImportMatter.bIndividualFile = true;
    
    % Actually importing the substance data now. To make this less
    % programming effort, we create some variables to switch between
    % isochoric and isobaric data.
    csFileName   = {[sTarget,'_Isochoric_'],[sTarget,'_Isobaric_']};
    csStructName = {'tIsochoricData','tIsobaricData'};
    
    for iI = 1:2
        % Read header File
        iFileID  = fopen(strrep(['lib/+matterdata/',csFileName{iI},'HeaderFile.csv'], '/', filesep));
        csInput  = textscan(iFileID, '%s', 'Delimiter','\n');
        csInput  = csInput{1};
        sInput_1 = csInput{1};
        sInput_2 = csInput{2};
        
        csColumnNames = textscan(sInput_1,'%s','Delimiter',',');
        csColumnNames = csColumnNames{1};
        
        % To make the following code a little simpler, we create an integer
        % variable for the number of columns here.
        iNumberOfColumns = length(csColumnNames);
        
        % So we can use the csColumnNames as struct field names, we need to
        % clean them up a little.
        csColumnNames = strrep(csColumnNames,'.','');
        csColumnNames = strrep(csColumnNames,' ','');
        csColumnNames = strrep(csColumnNames,'-','');
        
        csUnits = textscan(sInput_2,'%s','Delimiter',',');
        csUnits = csUnits{1};
        
        % Create tColumns struct
        % To improve the matter table performance, by avoinding frequent calls
        % find() to get the column indices, we add a struct with the property
        % names as keys and their indices in the ttxMatter struct as values.
        % While we're at it, we'll also create a struc saving the units for
        % each indiviual value.
        
        % First create the empty structs
        ttxImportMatter.(csStructName{iI}).tColumns = struct();
        ttxImportMatter.(csStructName{iI}).tUnits   = struct();
        
        % Now go through all of the columns and save the data into the
        % strucs
        for iJ = 1:iNumberOfColumns
            ttxImportMatter.(csStructName{iI}).tColumns.(csColumnNames{iJ}) = iJ;
            ttxImportMatter.(csStructName{iI}).tUnits.(csColumnNames{iJ})   = csUnits{iJ};
        end
        
        % Creating the file name
        sFileName = strrep(['lib/+matterdata/',csFileName{iI},'DataFile.csv'], '/', filesep);
        mfRawData = dlmread(sFileName,',');
        
        % We need to initialize three smaller matrices with enough space to
        % hold all values. So first we need to find out, how many values
        % for each phase are in the raw data. We also need to create some
        % empty structs: One for each phase and then within these we create
        % a struct for possible interpolations that can be saved into the
        % matter table for increased simulation performance. And
        % to make searching in the matter table itself faster, we also add a
        % boolean variable as an indicator if there are interpolations
        % present at all.
        % To make the code more compact, we'll do it all in one for-loop.
        
        % A struct to help with naming of the structs
        csPhaseStructNames = {'tSolid','tLiquid','tGas','tSupercritical'};
        
        for iJ = 1:length(csPhaseStructNames)
            % Creating the empty structs
            ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ})  = struct();
            ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ}).tInterpolations = struct();
            ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ}).bInterpolations = false;
            
            % Getting the number of items for this phase
            iNumberOfPhaseValues = sum(mfRawData(:,ttxImportMatter.(csStructName{iI}).tColumns.Phase) == iJ);
            % Initializing the matrix
            ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ}).mfData  = NaN(iNumberOfPhaseValues,  iNumberOfColumns);
        end
        
        % Need a small array to keep track of the matrix indexes
        aiCurrentIndex = [ 1 1 1 1 ];
        
        % Now we can cycle through the entire raw data matrix and
        % distribute the data into the three phase specific matrices.
        for iJ = 1:length(mfRawData)
            iPhaseID = mfRawData(iJ,ttxImportMatter.(csStructName{iI}).tColumns.Phase);
            sPhaseStructName = csPhaseStructNames{iPhaseID};
            iIndex = aiCurrentIndex(iPhaseID);
            ttxImportMatter.(csStructName{iI}).(sPhaseStructName).mfData(iIndex,:) = mfRawData(iJ,:);
            aiCurrentIndex(iPhaseID) = aiCurrentIndex(iPhaseID) + 1;
        end
        
        % In an effort to further increase the performance of the matter table
        % by avoiding frequent calls of min() and max(), we include these
        % extremes in the ttxMatter struct statically.
        
        for iJ = 1:length(csPhaseStructNames)
            
            % First create the empty struct
            ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ}).ttExtremes = struct();
            
            % Now we go through each column, using the iNumberOfColumns variable we
            % created earlier, create another struct for each individual property,
            % with two key/value pairs: one for the minimum and one for the maximum
            % value.
            for iK = 1:iNumberOfColumns
                % We can't find min and max for the 'Phase' column, but for every
                % other one we can.
                if ~strcmp(csColumnNames{iK}, 'Phase')
                    % Creating the struct
                    sStructName = ['t',csColumnNames{iK}];
                    ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ}).ttExtremes.(sStructName) = struct();
                    
                    try
                        % Getting the min and max values
                        fMin = min(ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ}).mfData(:,iK));
                        fMax = max(ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ}).mfData(:,iK));
                    catch
                        % There may be only NaNs in the last column, if so we just
                        % don't add the property struct to tExtremes
                        break;
                    end
                    
                    % Some of the columns may contain only NaNs, in this case we
                    % don't add the property struct to tExtremes
                    if ~(isempty(fMin) || isempty(fMax))
                        % Writing the values to the struct
                        ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ}).ttExtremes.(sStructName).Min = fMin;
                        ttxImportMatter.(csStructName{iI}).(csPhaseStructNames{iJ}).ttExtremes.(sStructName).Max = fMax;
                    end
                end
            end
        end
        
        % For mixtures or adsorbed material it is also necessary to save
        % all matter data independent from its phase
        ttxImportMatter.(csStructName{iI}).tAll  = struct();
        ttxImportMatter.(csStructName{iI}).tAll.tInterpolations = struct();
        ttxImportMatter.(csStructName{iI}).tAll.bInterpolations = false;
            
        ttxImportMatter.(csStructName{iI}).tAll.mfData = mfRawData;
        for iK = 1:iNumberOfColumns
            % We can't find min and max for the 'Phase' column, but for every
            % other one we can.
            if ~strcmp(csColumnNames{iK}, 'Phase')
                % Creating the struct
                sStructName = ['t',csColumnNames{iK}];
                ttxImportMatter.(csStructName{iI}).tAll.ttExtremes.(sStructName) = struct();

                try
                    % Getting the min and max values
                    fMin = min(ttxImportMatter.(csStructName{iI}).tAll.mfData(:,iK));
                    fMax = max(ttxImportMatter.(csStructName{iI}).tAll.mfData(:,iK));
                catch
                    % There may be only NaNs in the last column, if so we just
                    % don't add the property struct to tExtremes
                    break;
                end

                % Some of the columns may contain only NaNs, in this case we
                % don't add the property struct to tExtremes
                if ~(isempty(fMin) || isempty(fMax))
                    % Writing the values to the struct
                    ttxImportMatter.(csStructName{iI}).tAll.ttExtremes.(sStructName).Min = fMin;
                    ttxImportMatter.(csStructName{iI}).tAll.ttExtremes.(sStructName).Max = fMax;
                end
            end
        end
    end
end

end


