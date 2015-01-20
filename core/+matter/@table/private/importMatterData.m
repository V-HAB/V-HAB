function [ ttxImportMatter, csWorksheets ] = importMatterData(sFile, sWorksheetname)
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
    [~, emptyColumns] = find(strcmp(import.text(1,:),''));
    iTableLength = emptyColumns(1)-1;
    
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
                    if ~isnan(import.num(iRows(z)-2,j-3))
                        ttxImportMatter.(scSubstances{iI}).ttxPhases.(import.text{iRows(z),3}).(import.text{2,j}) = import.num(iRows(z)-2,j-3);
                    end
                end
                
            end
            
        end
    end
    %% import specific substance worksheet
else
%     % first look if data is not already imported
%     % if data is imported check size of imported data (data from MatterData has max size of 5)
%     if isfield(ttxMatter, sWorksheetname) && length(ttxMatter.(sWorksheetname).import.raw(:,1)) < 6
%         
%         % save substance data from worksheet MatterData
%         ttxImportMatter.MatterData.raw  = ttxMatter.(sWorksheetname).import.raw;
%         ttxImportMatter.MatterData.num  = ttxMatter.(sWorksheetname).import.num;
%         ttxImportMatter.MatterData.text = ttxMatter.(sWorksheetname).import.text;
%         
%         % data is already imported -> get back
%     elseif isfield(this.ttxMatter, sWorksheetname)
%         return;
%     end
    
    % import worksheet sWorksheetname
    [import.num, import.text, import.raw] = customXLSread(sFile, sWorksheetname);
    %[import.num, import.text, import.raw] = xlsread(sFile, sWorksheetname);
    
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
    [~, emptyColumns] = find(strcmp(import.text(1,4:end),''));
    iNumberOfConstants = emptyColumns(1)-1;
    
    % save all constants of substances defined in first four
    % rows, since we ignore the first three columns, we have to
    % add 3 to the end of the range
    for iI = 4:(iNumberOfConstants + 3)
        if ~isempty(import.text{3,iI}) &&  ~isnan(import.num(1,iI))
            ttxImportMatter.(import.text{3,iI}) = import.num(1,iI);
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
    
    % look if some values safed as kJ -> has to convert do J (*1000)
    iTableLength = size(ttxImportMatter.import.text,2);
    for iI = 1:iTableLength
        if strncmp(ttxImportMatter.import.text{6,iI}, 'kJ', 2)
            ttxImportMatter.import.text{6,iI} = strrep(ttxImportMatter.import.text{6,iI}, 'kJ', 'J');
            ttxImportMatter.import.num(:,iI)  = ttxImportMatter.import.num(:,iI)*1000;
        end
    end
    
end

end


