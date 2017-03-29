function [ ttxImportNutrientData ] = importNutrientData()
% this function reads the PlantParameters.csv file

    % At first we'll just read the first line of the file, this determines
    % the width of the actual table. So if more data columns are added in
    % the future, this code won't have to change so much.
    
    %% Import data from PlantParameters.csv file
    
    % Open the file
    iFileID = fopen(strrep('lib/+components/+PlantModuleV2/+food/+data/NutrientData.csv','/',filesep), 'r');
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
    csRawData = repmat({''},length(csImportCell{1}),length(csImportCell));
    % Copying the data from the imported cell into the raw data cell
    for iFirstVariableColumn = 1:length(csImportCell)-1
        csRawData(1:length(csImportCell{iFirstVariableColumn}),iFirstVariableColumn) = csImportCell{iFirstVariableColumn};
    end
    % Creating an array full of NaNs
    afNumericData = NaN(size(csImportCell{1},1),size(csImportCell,2));
    
    % The first column is text, so we just have to look at the
    % columns 2 and later
    for iFirstVariableColumn = 2:length(csImportCell)
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
    csRawStringColumns  = csRawData(:, 1);
    
    
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
    % while density and heat capacity are not constant the values will be
    % saved here to be used as standard values with which e.g. adsorber
    % that contain solids and gases/liquids can be calculated
    iFirstVariableColumn = find(strcmp(csVariableNames,'iUSDAID'));
    
    % Initialize the struct in which all substances are later stored
    ttxImportNutrientData = struct();
    
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
        if isfield(ttxImportNutrientData,csSubstances{iI})
            continue;
        end
        
        % set substancename as fieldname
        ttxImportNutrientData.(csSubstances{iI}) = [];
        
        % select all rows of that substance
        % substances can have more than one phase
        aiRows = find(strcmp(csSubstances,csSubstances{iI}));
        
        if ~isempty(aiRows)
            % Store all data of current substance in the sub-struct of
            % ttxImportNutrientData.
            
            % Store the full name of the substance
            ttxImportNutrientData.(csSubstances{iI}).sPlantSpecies = csRawData{aiRows(1), 1};
         
            
            % go through all phases and save all remaining properties for that specific phase
            for iJ = 1:length(aiRows)
                for iK = iFirstVariableColumn:iNumberOfColumns
                    ttxImportNutrientData.(csSubstances{iI}).(csColumnNames{iK}) = csRawData{aiRows(iJ),iK};
                end
            end
            
            % Since none of the substances in the "Matter Data" worksheet
            % will enable interpolation of their properties, we can just
            % set the variable to false here.
            %TODO Might not need this, so commented, remove if sure. 
            %ttxImportNutrientData.(csSubstances{iI}).bInterpolations = false;
            
            % Finally we add the tColumns and tUnits structs to every 
            % substance
            ttxImportNutrientData.(csSubstances{iI}).tColumns = tColumns;
            ttxImportNutrientData.(csSubstances{iI}).tUnits   = tUnits;
        end
    end
end

