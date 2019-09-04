function importNutrientData(this)
% this function reads nutrient data that was downloaded from the US Food
% Composition Database (https://ndb.nal.usda.gov/ndb/search/list) if you
% want to add additional food to V-HAB search for it in the database,
% download the corresponding CSV and add it to the folder
% core/+matter/+data/+NutrientData
    
    % get the file names for the available nutrient data
    csFiles = dir(strrep('core/+matter/+data/+NutrientData','/',filesep));
    csFiles = {csFiles.name};
    
    % remove non csv files
    cfCSV = regexp(csFiles, '.csv');
    mbCSV = true(1, length(cfCSV));
    for iFile = 1:length(cfCSV)
        if isempty(cfCSV{iFile})
            mbCSV(iFile) = false;
        end
    end
    csFiles = csFiles(mbCSV);
    
    % To convert the units in which the database provides information into
    % SI units we create a conversion struct:
    tConversion.g       = 1e-3;
    tConversion.mg      = 1e-6;
    tConversion.microg  = 1e-9;
    tConversion.kcal    = 4184;
    tConversion.kJ      = 1000;
    tConversion.IU      = 1;
    
    ttxImportNutrientData = struct();
    
    % Add lines with the unique part of the Nutrient Data for: row from the
    % downloaded CSV file and provide a custom name if you want custom food
    % names
    csCustomFoodNames           = {'Beans, snap'; 'SnapBeans'};
    csCustomFoodNames(:,end+1)  = {'Beans, kidney'; 'KidneyBeans'};
    csCustomFoodNames(:,end+1)  = {'Onions, young green'; 'GreenOnions'};
    csCustomFoodNames(:,end+1)  = {'ORGANIC WHOLE GROUND TIGERNUT'; 'Chufa'};
    
    % now loop through the files
    for iFile = 1:length(csFiles)
        %% Open File and load the data
        iFileID = fopen(strrep(['core/+matter/+data/+NutrientData/', csFiles{iFile}],'/',filesep), 'r');
        
        % This is a cell array of cells, so we 'unpack' one level to get the
        % actual string.
        csImport = textscan(iFileID, '%s', 'Delimiter', '\n');
        csImport = csImport{1};
        
        % Now we get the type of food for which this data file contains
        % information
        acData = cell(length(csImport),1);
        iHeaderRows = [];
        iEndRow = [];
        for iRow = 1:length(csImport)
            if ~isempty(regexp(csImport{iRow}, 'Nutrient data for:', 'once'))
                sInitialSplitString = regexp(csImport{iRow}, ': ','split');
                
                bCustomFoodName = false;
                for iCustomFoodName = 1:length(csCustomFoodNames)
                    if ~isempty(regexp(sInitialSplitString{2}, csCustomFoodNames{1,iCustomFoodName}, 'once'))
                        bCustomFoodName = true;
                        sFoodName = csCustomFoodNames{2,iCustomFoodName};
                    end
                end
                if ~bCustomFoodName
                    splitStr = regexp(sInitialSplitString{2}, ',','split');
                    sFoodName = splitStr{1};
                    sFoodName = tools.normalizePath(sFoodName);
                    if isfield(ttxImportNutrientData, sFoodName)
                        sFoodName = tools.normalizePath(sInitialSplitString{2});
                    end
                end
            elseif ~isempty(regexp(csImport{iRow}, 'per 100 g', 'once'))
                sColumnString = regexp(csImport{iRow}, ',','split');
                for iColumn = 1:length(sColumnString)
                    if ~isempty(regexp(sColumnString{iColumn}, 'per 100 g', 'once'))
                        iDataColumn = iColumn;
                    end
                end
            elseif ~isempty(regexp(csImport{iRow}, 'Proximates', 'once'))
                iHeaderRows = iRow;
            end
            
            if ~isempty(iHeaderRows) && iRow > iHeaderRows
                cData = cell(1,0);
                if ~isempty(regexp(csImport{iRow}, '1,"', 'once'))
                    iEndRow = iRow - 1;
                    break
                end
                cTempData = regexp(csImport{iRow}, '"','split');
                if isempty(cTempData{1})
                    iEntry = 2;
                else
                    iEntry = 1;
                end
                cData{1, end+1} = cTempData{iEntry}; %#ok<AGROW>
                if length(cTempData) > 2
                    cTempData = regexp(cTempData{3}, ',','split');
                    cData(1, end+1:end+length(cTempData)-1) = cTempData(2:end);
                end
                acData{iRow} = cData;
            end
        end
        
        % tNutrientData = readtable(strrep(['core/+matter/+data/+NutrientData/', csFiles{iFile}],'/',filesep), 'HeaderLines', iHeaderRows);
        
        % Close the text file.
        fclose(iFileID);
        
        %% create a easy to access and read struct array from the data
        ttxImportNutrientData.(sFoodName) = struct();
        
        if isempty(iEndRow)
            iEndRow = length(acData);
        end
        sSubHeader = [];
        for iRow = (iHeaderRows + 1):iEndRow
            % First get the name of the row
            sRowName = acData{iRow};
            sRowName = sRowName{1};
            sRowName = regexprep(sRowName, '"', '');
            sRowName = tools.normalizePath(sRowName);
            if strcmp(sRowName, 'Footnotes')
                break
            end
            
            cData = acData{iRow};
            % Then check if a new "subheader" line is present (e.g.
            % Minerals or Vitamins)
            if length(cData) == 1
                sSubHeader = sRowName;
            else
                % since the data is given with different units, we have to
                % convert them to standard SI units to be compatible with
                % V-HAB
                sUnit = cData{2};
                
                if strcmp(sUnit, 'µg')
                    sUnit = 'microg';
                end
                
                % Times 10 because the data is per 100 g and we want it to
                % be per kg
                fData = tConversion.(sUnit) * 10 * str2double(cData{iDataColumn});
                
                if strcmp(sUnit, 'IU')
                    sUnitHeader = 'IU';
                elseif strcmp(sUnit, 'kcal')
                    sUnitHeader = 'Energy';
                else
                    sUnitHeader = 'Mass';
                end
                
                if ~isfield(ttxImportNutrientData.(sFoodName), sUnitHeader)
                    ttxImportNutrientData.(sFoodName).(sUnitHeader) = struct();
                end
                
                if isempty(sSubHeader)
                    ttxImportNutrientData.(sFoodName).(sUnitHeader).(sRowName) = fData;
                else
                    ttxImportNutrientData.(sFoodName).(sUnitHeader).(sSubHeader).(sRowName) = fData;
                end
            end
        end
    end
    
    csMassFields = fieldnames(ttxImportNutrientData.Strawberries.Mass);
    
    fTotalMass = 0;
    for iMassField = 1:length(csMassFields)
        if strcmp(csMassFields{iMassField}, 'Fiber__total_dietary') || strcmp(csMassFields{iMassField}, 'Sugars__total') || strcmp(csMassFields{iMassField}, 'Lipids')
            continue
        end
        
        xFieldValue = ttxImportNutrientData.Strawberries.Mass.(csMassFields{iMassField});
        if isa(xFieldValue, 'struct')
            csInternalFieldnames = fieldnames(xFieldValue);
            for iInternalField = 1:length(csInternalFieldnames)
                fTotalMass = fTotalMass + xFieldValue.(csInternalFieldnames{iInternalField});
            end
        else
            fTotalMass = fTotalMass + xFieldValue;
        end
    end
    
    %% Create Compound Matter Data entries based on imported nutrient data!
    
    % loop over all edible substances
    for iJ = 1:length(this.csEdibleSubstances)
        this.ttxMatter.(this.csEdibleSubstances{iJ}).txNutrientData = ttxImportNutrientData.(this.csEdibleSubstances{iJ});
        
        % csComposition = {'Carbohydrates', 'Protein', 'Fat', 'C'}
        csFieldName = fieldnames(this.ttxMatter.(this.csEdibleSubstances{iJ}).txNutrientData);
        
        fTotalMass = 0;
        for iField = 1:length(csFieldName)
            if ~isempty(regexp(csFieldName{iField}, 'Mass', 'once')) && isempty(regexp(csFieldName{iField}, 'EnergyMass', 'once'))
                fTotalMass = fTotalMass + this.ttxMatter.(this.csEdibleSubstances{iJ}).txNutrientData.(csFieldName{iField});
            end
        end
        this.defineCompoundMass(this.csEdibleSubstances{iJ}, csComposition)
    end
end

