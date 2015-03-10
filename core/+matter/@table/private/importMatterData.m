function [ ttxImportMatter, csWorksheets ] = importMatterData(this, sFile, sWorksheetname)
% Import function that handles import from substances worksheet for
% one substance or at initialisation the import from worksheet MatterData.
% First it looks if substancedata is already imported (for a specific substance).
% After import with xlsread it gets the data in the right
% format for later use
%
% MatterImport returns
%  ttxImportMatter - struct with all data
%  csWorksheets    - cell array with the names of all the
%                    worksheets in the Excel file
%
% input parameters
% sFile: complete filename of MatterXLS
% sWorksheetname: worksheet name

% store all worksheets from Excel file and look if file is readable
% worksheetnames used in FindProperty to look if maybe more
% data is available
[sStatus, csWorksheets] = xlsfinfo(sFile);

if ~any(strcmp(sStatus, {'Microsoft Excel Spreadsheet', 'Microsoft Macintosh Excel Spreadsheet'}))
    % this is not going to work...
    this.throw('table:MatterImport',sprintf('File %s has wrong format for MatterImport',sFile));
end

%% import worksheet MatterData (standard Mattertable)
% this is executed at initialisation (from class simulation)
if strcmp(sWorksheetname, 'MatterData') && any(strcmpi(csWorksheets, 'MatterData'))
    
    % import of worksheet
    [import.num, import.text, import.raw] = customXLSread(sFile, sWorksheetname);

    % Search for empty cell in first row.; Column before is last
    % Tablecolumn. All data after that is not imported. Then
    % store table length 
    [~, aEmptyColumns] = find(strcmp(import.text(1,:),''));
    if isempty(aEmptyColumns)
        iTableLength = length(import.text(1,:));
    else
        iTableLength = aEmptyColumns(1)-1;
    end
    
    % Storing the column of the melting point
    % ("codename" of first property to store in phase) to
    % save all properties. The properties to the left of
    % melting point are considered constant and independent of
    % phase, temperature, pressure, etc.
    % NOTE: Currently there is only one constant property,
    % which is molar mass. We are leaving this in here though
    % just in case another constant property is added in the
    % future.
    iColumn = find(strcmp(import.text(2,:),'fMeltPoint'));
    
    % only unique substances are needed
    scSubstances = unique(import.text(3:end,1));
    
    % Initialize the struct in which all substances are later stored
    ttxImportMatter = struct;
    
    % To improve the matter table performance, by avoinding frequent calls 
    % find() to get the column indices, we add a struct with the property 
    % names as keys and their indices in the ttxMatter struct as values.
    
    % First create the empty struct
    tColumns = struct();
    
    % Sometimes there are empty columns at the end, so we need to know how
    % many. find() returns a vector, so we use array index 1 to be sure to
    % get the first one.
    [~, aEmptyColumns] = find(strcmp(import.text(1,:),''));
    
    if isempty(aEmptyColumns)
        iNumberOfColumns = length(import.text(5,:));
    else
        iNumberOfColumns = aEmptyColumns(1) - 1;
    end

    % Now we go through all columns and create the key/value pairs
    % accordingly
    for iI = 1:iNumberOfColumns
        sPropertyName = strrep(import.text{1,iI},' ','');
        tColumns.(sPropertyName) = iI;
    end
    
    % go through all unique substances
    for iI = 1:length(scSubstances)
        % set substancename as fieldname
        ttxImportMatter.(scSubstances{iI}) = [];
        %ttxImportMatter = setfield(ttxImportMatter, scSubstances{i},'');
        
        % select all rows of that substance
        % substances can have more than one phase
        iRows = find(strcmp(import.text(3:end,1),scSubstances{iI}));
        if ~isempty(iRows)
            % rownumbers of .num and .text/.raw are 2 rows different because of headers
            iRows = iRows +2;
            % store all data of current substance
            ttxImportMatter.(scSubstances{iI}).import.num = import.num(iRows-2,:);
            ttxImportMatter.(scSubstances{iI}).import.num(:,iTableLength+1:end) = []; % overhead not needed
            ttxImportMatter.(scSubstances{iI}).import.text = import.text(1:2,:);
            ttxImportMatter.(scSubstances{iI}).import.text = [ttxImportMatter.(scSubstances{iI}).import.text; import.text(iRows,:)];
            ttxImportMatter.(scSubstances{iI}).import.text(:,iTableLength+1:end) = []; % overhead not needed
            ttxImportMatter.(scSubstances{iI}).import.raw = import.raw(1:2,:);
            ttxImportMatter.(scSubstances{iI}).import.raw = [ttxImportMatter.(scSubstances{iI}).import.raw; import.raw(iRows,:)];
            ttxImportMatter.(scSubstances{iI}).import.raw(:,iTableLength+1:end) = []; % overhead not needed
            
            % go through all properties before density
            % this properties are constant and only needed one time
            for j = 4:iColumn-1
                if ~isnan(import.num(iRows(1)-2,j-3))
                    ttxImportMatter.(scSubstances{iI}).(import.text{2,j}) = import.num(iRows(1)-2,j-3);
                end
            end
            
            % go through all phases and save all remaining properties for that specific phase
            for z = 1:length(iRows)
                for j = iColumn:iTableLength
                    try
                    if ~isnan(import.num(iRows(z)-2,j-3))
                        ttxImportMatter.(scSubstances{iI}).ttxPhases.(import.text{iRows(z),3}).(import.text{2,j}) = import.num(iRows(z)-2,j-3);
                    end
                    catch
                        keyboard(); 
                    end
                end
                
            end
            
            % Since none of the substances in the "Matter Data" worksheet
            % will enable interpolation of their properties, we can just
            % set the variable to false here. 
            ttxImportMatter.(scSubstances{iI}).bInterpolations = false;
            
            % Finally we add the tColumns struct to every substance 
            ttxImportMatter.(scSubstances{iI}).tColumns = tColumns;
        end
    end
    %% import specific substance worksheet
else
    
    % import worksheet sWorksheetname
    [import.num, import.text, import.raw] = customXLSread(sFile, sWorksheetname);
    
    % save data for later use
    ttxImportMatter.import.text    = import.text;
    ttxImportMatter.import.num     = import.num;
    ttxImportMatter.import.raw     = import.raw;
    ttxImportMatter.SubstancesName = import.text{1,1};
    
    % Finding the empty cells in the text array of the first
    % row, this way we can figure out, how many constants there
    % are in this specific worksheet
    % Since the first three cells are irrelevant, we start
    % looking in the fourth column
    [~, aEmptyColumns] = find(strcmp(import.text(1,4:end),''));
    iNumberOfConstants = aEmptyColumns(1)-1;
    
    % save all constants of substances defined in first four
    % rows, since we ignore the first three columns, we have to
    % add 3 to the end of the range
    for iI = 4:(iNumberOfConstants + 3)
        if ~isempty(import.text{3,iI}) &&  ~isnan(import.num(1,iI))
            
            ttxImportMatter.(import.text{3,iI}) = import.num(1,iI);
            
            if strcmp(import.text{3,iI}, 'fMolMass')
                ttxImportMatter.fMolarMass = import.num(1,iI) / 1000;
            end
        end
    end
     
    % numeric import is mostly minor than other because in
    % the first lines are often no numbers
    % for easier handling in later functions get this the
    % same size
    iLengthRaw = size(import.raw,1);
    iLengthNum = size(import.num,1);
    if iLengthRaw > iLengthNum
        afNewArray(iLengthRaw,size(import.num,2)) = 0;
        afNewArray(:,:) = nan;
        afNewArray((iLengthRaw-iLengthNum)+1:end,:) = ttxImportMatter.import.num;
        ttxImportMatter.import.num = afNewArray;
    end
    
    
    % To improve the matter table performance, by avoinding frequent calls 
    % find() to get the column indices, we add a struct with the property 
    % names as keys and their indices in the ttxMatter struct as values.
    
    % First create the empty struct
    ttxImportMatter.tColumns = struct();
    
    % Sometimes there are empty columns at the end, so we need to know how
    % many. find() returns a vector, so we use array index 1 to be sure to
    % get the first one.
    [~, aEmptyColumns] = find(strcmp(import.text(5,:),''));
    
    if isempty(aEmptyColumns)
        iNumberOfColumns = length(import.text(5,:));
    else
        iNumberOfColumns = aEmptyColumns(1) - 1;
    end

    % Now we go through all columns and create the key/value pairs
    % accordingly
    for iI = 1:iNumberOfColumns
        % We can skip the temperature in celcius
        if ~strcmp(import.text{6,iI}, 'C')
            sPropertyName = strrep(import.text{5,iI},' ','');
            ttxImportMatter.tColumns.(sPropertyName) = iI;
        end
    end
    
    % In an effort to further increase the performance of the matter table
    % by avoiding frequent calls of min() and max(), we include these
    % extremes in the ttxMatter struct statically. 
    
    % First create the empty struct
    ttxImportMatter.ttExtremes = struct();
    
    % Now we go through each column, using the iNumberOfColumns variable we
    % created earlier, create another struct for each individual property,
    % with two key/value pairs: one for the minimum and one for the maximum
    % value.
    for iI = 1:iNumberOfColumns
        % We can't find min and max for the 'Phase' column, but for every
        % other one we can.
        if ~strcmp(import.text{5,iI}, 'Phase')
            % Creating the struct
            sStructName = ['t',strrep(import.text{5,iI},' ','')];
            ttxImportMatter.ttExtremes.(sStructName) = struct();
            
            try
                % Getting the min and max values
                fMin = min(import.num(:,iI));
                fMax = max(import.num(:,iI));
            catch
                % There may be only NaNs in the last column, if so we just
                % don't add the property struct to tExtremes
                break;
            end
            
            % Some of the columns may contain only NaNs, in this case we 
            % don't add the property struct to tExtremes
            if ~(isnan(fMin) || isnan(fMax))
                % Writing the values to the struct
                ttxImportMatter.ttExtremes.(sStructName).Min = fMin;
                ttxImportMatter.ttExtremes.(sStructName).Max = fMax;
            end
        end
    end
    
    
    % Finally, we create a struct for possible interpolations that can be
    % save into the matter table for increased simulation performance. And
    % to make searching in the matter table itself faster, we also add a
    % boolean variable as an indicator if there are interpolations present
    % at all. 
    tInterpolations = struct();
    ttxImportMatter.tInterpolations = tInterpolations;
    ttxImportMatter.bInterpolations = false; 
    
% We shouldn't need this because all of the values in the matter table MUST
% be in Joule
%     % look if some values saved as kJ -> has to convert do J (*1000)
%     iTableLength = size(ttxImportMatter.import.text,2);
%     for iI = 1:iTableLength
%         if strncmp(ttxImportMatter.import.text{6,iI}, 'kJ', 2)
%             ttxImportMatter.import.text{6,iI} = strrep(ttxImportMatter.import.text{6,iI}, 'kJ', 'J');
%             ttxImportMatter.import.num(:,iI)  = ttxImportMatter.import.num(:,iI)*1000;
%         end
%     end
    
end

end


